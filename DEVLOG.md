# DEVLOG — kotoba-api

コミットごとに作業内容を記録。最新のエントリが上。
設計判断・トレードオフを含む作業は必ず記録。些細な修正は省略可。

## 2026-07-05

### GeminiService のモデルを gemini-3.5-flash に変更

- `GeminiService::API_URL` の `gemini-2.0-flash` を `gemini-3.5-flash` に変更
  - `gemini-2.0-flash` が deprecated 済みで無料枠 quota が 0 になっており、DailyStory 生成が毎日 429 エラーで失敗していた
  - CloudWatch の ECS ログで `Quota exceeded ... limit: 0, model: gemini-2.0-flash` を確認して特定
  - `gemini-3.5-flash` は無料枠が生きているモデルとして採用

## 2026-06-28

### GeminiService PRレビュー追加対応

- `JSON::ParserError` を明示的に rescue し、デバッグ可能なエラーメッセージを生成
  - `rescue StandardError` に飲まれていたが、原因特定のためメッセージを具体化
- `example_sentence` / `example_sentence_korean` の blank チェックを追加
  - `AiContent` は `validates presence: true` を持つが `insert_all!` は validation をスキップするため GeminiService 側で事前検証が必要
- `res.body` を 500 文字に切り詰めてログ肥大を防止

### GeminiService コードレビュー対応

- `open_timeout = 10` を追加。TCP 接続ハングによるワーカースレッド無限ブロックを防止
- API key を URL query param から `x-goog-api-key` ヘッダーに移動。ログへの漏洩を防ぐ
- `data["examples"]` nil ガードを追加。`"examples"` キー自体が返らない場合の `NoMethodError` を防止
- `data["story"].blank?` チェックを追加。空ストーリーのサイレント保存を防止
- `require "json"` 削除（Rails が既にロード済み）

### DailyStory 生成パイプライン刷新: Lambda → Rails + Gemini 直接呼び出し

- `GeminiService` を新規作成。単語10個を受け取り、日本語ストーリー・韓国語翻訳・単語別例文を一括生成
  - **設計判断 (Method B 採用)**: Lambda は EventBridge の trigger 役に専念し、Gemini API 呼び出しは Rails 側に移管した。Lambda で Gemini を呼ぶと Lambda の timeout / メモリ / エラーハンドリングが複雑になる。Rails 側に寄せることでトランザクション・エラーログ・retry ロジックを一元管理できる
  - Gemini の JSON レスポンスは `word_id` を信頼せずインデックス順でマッピング。Gemini が存在しない ID を返しても問題なく動作する
  - `read_timeout = 55s`（Gemini のレスポンス遅延対策）
- `Webhooks::DailyStoriesController#create` を全面刷新。外部ペイロード受け取りをやめ `DailyWordSelectorService → GeminiService → DailyStoryCreationService` の内部パイプラインに統一
- `webhooks/daily_stories_spec` を新アーキテクチャに合わせて書き直し。`DailyWordSelectorService` と `GeminiService` を stub して単体テストとして高速に実行できる構成に変更

## 2026-06-27

### セキュリティレビュー対応: JWT署名検証・認可テスト追加

- `find_user_for_refresh` の `JWT.decode` で第3引数 `false`（署名検証オフ）→ `true` に修正。`verify_expiration: false` で有効期限切れのみ許容する意図を明示
  - **設計判断**: 従来は「有効期限切れトークンを受け入れるため署名検証も無効化」していたが、JWT gem の `verify_expiration: false` オプションで「署名は検証しつつ exp のみ無視」できる。refresh token の bcrypt 検証が最終防衛線だが、署名検証を残すことで改ざんトークンによる user_id 詐称の余地を排除
- `bookmarks_spec`: 他ユーザーがブックマークした単語を DELETE しようとした場合に 404 を返し、かつ他ユーザーのレコードが消えないことを検証するテストを追加
- `study_sessions_spec`: PUT 実行時に他ユーザーのセッション（word_day_id / streak_days）が変更されないことを検証するデータ分離テストを追加

### 本番デプロイ完了・API疎通確認

- ECS コンテナが連続クラッシュする問題を一連の修正で解消し、プロダクション API の疎通を確認
- **問題①: `Missing secret_key_base`** — `credentials.yml.enc` はイメージに含まれているが `RAILS_MASTER_KEY` が ECS に渡っていなかった。SSM に `rails_master_key` パラメータを追加し、ECS タスク定義の secrets に `RAILS_MASTER_KEY` として注入するよう変更
- **問題②: `The 'cache' database is not configured`** — `production.rb` で Solid Cache / Queue を無効化しても gem 自体がロード時に `connects_to` を実行するため、設定変更だけでは不十分だった。Gemfile から `solid_cache` / `solid_queue` を完全削除し、関連ファイル (`db/cache_schema.rb`、`db/queue_schema.rb`、`bin/jobs`、`puma.rb` の SolidQueue プラグイン行、`recurring.yml` の production 設定) もあわせて削除
  - **設計判断**: このプロジェクトの AI 処理は Lambda 側で行うため、Rails の非同期 Job / キャッシュ層はそもそも不要。gem ごと削除が正しい判断
- **問題③: CloudFront 504 (ポート不一致)** — Thruster は port 80 で listen するが、ECS portMappings・CloudFront origin・Security Group が全て 3000 のままだった。3 ファイルを 80 に修正
  - Terraform の `cloudfront.tf` に `lifecycle { ignore_changes = [origin] }` があったため `http_port` 変更が適用されなかった。lifecycle を一時削除 → apply → 復元の手順で回避
- **問題④: RDS が stopped 状態** — EC2 は自動中止スケジュールで起動しているが RDS は stopped のまま。ECS タスクが `db:prepare` で DB 接続待ちのままフリーズし、コンテナ内にログが出力されず原因特定に時間がかかった
  - RDS を手動 start 後に force-new-deployment で解消
- 最終確認: `POST /api/v1/auth/signup` → 201、`POST /api/v1/auth/login` → access token 発行、`GET /api/v1/words` → N5 単語 20 件返却

### 本番デプロイ完了・API疎通確認

- ECS コンテナが連続クラッシュする問題を一連の修正で解消し、プロダクション API の疎通を確認
- **問題①: `Missing secret_key_base`** — `credentials.yml.enc` はイメージに含まれているが `RAILS_MASTER_KEY` が ECS に渡っていなかった。SSM に `rails_master_key` パラメータを追加し、ECS タスク定義の secrets に `RAILS_MASTER_KEY` として注入するよう変更
- **問題②: `The 'cache' database is not configured`** — `production.rb` で Solid Cache / Queue を無効化しても gem 自体がロード時に `connects_to` を実行するため、設定変更だけでは不十分だった。Gemfile から `solid_cache` / `solid_queue` を完全削除し、関連ファイル (`db/cache_schema.rb`、`db/queue_schema.rb`、`bin/jobs`、`puma.rb` の SolidQueue プラグイン行、`recurring.yml` の production 設定) もあわせて削除
  - **設計判断**: このプロジェクトの AI 処理は Lambda 側で行うため、Rails の非同期 Job / キャッシュ層はそもそも不要。gem ごと削除が正しい判断
- **問題③: CloudFront 504 (ポート不一致)** — Thruster は port 80 で listen するが、ECS portMappings・CloudFront origin・Security Group が全て 3000 のままだった。3 ファイルを 80 に修正
  - Terraform の `cloudfront.tf` に `lifecycle { ignore_changes = [origin] }` があったため `http_port` 変更が適用されなかった。lifecycle を一時削除 → apply → 復元の手順で回避
- **問題④: RDS が stopped 状態** — EC2 は自動中止スケジュールで起動しているが RDS は stopped のまま。ECS タスクが `db:prepare` で DB 接続待ちのままフリーズし、コンテナ内にログが出力されず原因特定に時間がかかった
  - RDS を手動 start 後に force-new-deployment で解消
- 最終確認: `POST /api/v1/auth/signup` → 201、`POST /api/v1/auth/login` → access token 発行、`GET /api/v1/words` → N5 単語 20 件返却

## 2026-06-26

### 本番環境のDB接続をDATABASE_URLに統一・Solid Cache/Queue無効化

- `database.yml` の production を Rails 8 デフォルトのマルチDB構成 (`primary` / `cache` / `queue`) から `url: ENV["DATABASE_URL"]` の単一DB設定に変更
- **原因**: ECS から `DATABASE_URL` が注入されていたが、マルチDB設定では primary にしか適用されず、cache/queue DB がローカルソケットへの接続を試みて `db:prepare` が失敗していた
- `production.rb` の Solid Cache / Solid Queue を無効化 (`cache_store → memory_store`、`solid_queue` 設定を削除)
  - このプロジェクトの AI 処理は Lambda 側で実行するため、Rails の Active Job / キャッシュ層は不要
- nokogiri を 1.19.4 にアップデート (Use-After-Free 系脆弱性 8件対応)
- Dependabot 自動 PR を無効化 (`open-pull-requests-limit: 0`)
  - CI に bundler-audit + brakeman が既にあるため重複。自動 PR がリポジトリを散らかす問題を解消

## 2026-05-27

### GitHub Actions デプロイ workflow 追加

- `.github/workflows/deploy.yml` を追加
- `workflow_run` トリガーで CI (scan_ruby / lint / test) が全て成功した後にのみ deploy を実行。CI 失敗でもデプロイが走る問題を防ぐため。
- ECR に `:sha` と `:latest` の2タグを同時 push。`:latest` は Docker layer cache のソースとして次回ビルド時に活用し、ビルド時間を短縮。
- `wait-for-service-stability: false`: t2.micro 1台 + `minimum_healthy_percent=0` 構成では安定化待機がタイムアウトを引き起こすため意図的に無効化。

## 2026-05-04

### アクセストークン期限切れ後の強制ログアウト問題を修正

- `/auth/refresh` が `skip_before_action` に含まれておらず、`authenticate_user!` が実行されていたため、refresh リクエスト時に "Authorizationヘッダーがありません" 401 を返すバグを修正
- `skip_before_action` に `refresh` を追加
- `find_user_for_refresh` を新設: Authorization ヘッダーがある場合は access token から user_id を取得（`verify: false` で期限切れ許容）、ない場合は body の `user_id` を fallback として使用
- **設計判断**: ページリロード後は accessToken がメモリから消えるため、body の `user_id` を受け入れる仕組みが必須。user_id は非秘匿情報であり、実際の認証は bcrypt 検証が担保するため安全性に問題なし
- spec: ヘッダーなし・user_id あり（正常系）、ヘッダーなし・user_id なし（異常系）の 2 ケースを追加

### パスワード変更エンドポイントを追加

- `PUT /api/v1/profile/password` を新設。`current_password` で本人確認後、`new_password` に更新
- `new_password_confirmation` はフロント側で検証済みのため受け取らない設計にした（バックエンドで二重検証しても意味がない）
- `current_password` を必須にした理由: セッション（JWTトークン）が漏洩しても、パスワード変更まで乗っ取られないようにするため
- `User` モデルに `validates :password, length: { minimum: 6 }, allow_nil: true` を追加（新規登録・変更時のみ検証、`nil` は既存レコードの通常更新をブロックしない）
- RSpec: 4ケース追加（正常系1、異常系3）

## 2026-05-02

### タイムゾーンを Asia/Tokyo に統一

- `config.time_zone = "Asia/Tokyo"` を設定。これまで未設定（UTC デフォルト）だったため、DB の `updated_at` が UTC 表示となり混乱を招いていた。
- `StudySession#calculate_streak` 内の `.in_time_zone("Asia/Tokyo")` 呼び出しを削除。全体 timezone が JST になったため `Time.current.to_date` / `updated_at.to_date` が自動的に JST 基準となる。
- **設計判断**: timezone をグローバルで統一することで、今後どこで `Time.current` を使っても JST 基準になり、計算ロジック内での明示的な変換が不要になる。

### spec/factory の Date.today を Date.current に統一

- `Date.today` はシステム timezone（UTC）基準のため、CI など UTC 環境では JST と日付がずれる可能性があった。
- `Date.current` は `Time.zone.today` の alias で `config.time_zone` に従う。timezone 統一に合わせ全 spec / factory を置換。

## 2026-04-26

### StudySession に streak_days を追加

- migration: `study_sessions` テーブルに `streak_days integer not null default 1` を追加。既存レコードは default 1 で補完。
- streak 計算ロジックを `StudySession#calculate_streak` として `before_save` コールバックに実装（`if: :persisted?` で新規作成時はスキップ）。コントローラーには一切書かない方針。
- **設計判断**: `before_save` 時点では `updated_at` がまだ旧値（ActiveRecord の Timestamp モジュールは `before_create/before_update` でタイムスタンプを更新するため）。これを利用して「前回の更新日時」と当日を比較する。
- **タイムゾーン**: 当初は `Time.current.in_time_zone("Asia/Tokyo")` を明示していたが、2026-05-02 に `config.time_zone = "Asia/Tokyo"` をグローバル設定したため、現在は `to_date` のみで JST 基準となっている。
- GET / PUT レスポンスの serialize に `streak_days` を追加。
- `doc/openapi.yml` の `StudySession` スキーマに `streak_days: integer` を追加。
- spec: 当日重複更新・昨日更新・2日以上経過の3ケースを追加（`travel_to` で時刻制御）。

## 2026-04-23

### Lambda → Rails Webhook エンドポイントの実装（POST /webhooks/daily_story）

- `Webhooks::DailyStoriesController` を新規実装。Lambda が Gemini で生成したストーリーデータを受け取り、`DailyStoryCreationService` に委譲する
- 認証は `X-Internal-Token` ヘッダーによる共有シークレット方式。`ENV.fetch("INTERNAL_API_KEY")` でデフォルト値なし — 未設定時は KeyError でサーバー起動を止める設計（デフォルト値 `""` にすると token 未送信で secure_compare が通過するため）
- エンドポイントは `/api/v1/` 配下ではなく `/webhooks/` 直下に配置。versioned client API と Lambda イベント受信を分離（`pay` gem 等の Rails 慣例に準拠）
- **冪等性**: `DailyStoryCreationService` を `[story, created]` タプル返却に変更。`find_by(story_date:)` で既存チェック → 存在すれば即返却。race condition は rescue で既存レコードを再取得して対応。重複 → 409 ではなく 200 を返すことで Lambda の再試行ループを防ぐ
- **ロギング**: 認証失敗（IP付き）・成功・エラーを `Rails.logger` で記録
- **nil ガード**: `@word_data&.size` で `words` キー未送信時の NoMethodError を防止
- **FK 違反の握り潰し**: 存在しない `word_id` は `InvalidForeignKey` を ArgumentError に変換し DB 構造の漏洩を防ぐ
- **INSERT 最適化**: `create!` × 20 回ループを `insert_all!` × 2 回に変更（単一トランザクション内）
- `doc/openapi.yml` に 200（冪等）・201・401・422・500 の各レスポンス定義を追加
- spec: 16ケース全パス（冪等性・nil ガード含む）

## 2026-04-21

### AIコンテンツエンジン + GET /api/v1/daily_story 実装

- `DailyWordSelectorService` を実装。ユーザーの `target_level` 最多レベルから未使用単語10個を優先抽出し、不足分は使用済み単語で補充する。複数モデル（User / Word / DailyStoryWord）にまたがるロジックのためService Objectとして分離。
- `DailyStoryCreationService` を実装。Lambda(Gemini)から受け取ったデータをひとつのトランザクションで DailyStory + DailyStoryWord×10 + AiContent×10 として保存。10個未満の場合は ArgumentError、story_date 重複は ActiveRecord::RecordInvalid でロールバック。
- `GET /api/v1/daily_story` を実装。`resource :daily_story`（singular resource）でルーティング。`includes(:words, :ai_contents)` + `index_by(&:word_id)` でN+1クエリを完全排除。`today` 固定ではなく `order(story_date: :desc).first` で最新ストーリーを返す設計にした（Lambdaの生成タイミングのずれに対応）。
- Lambda 側の POST エンドポイントはインフラ設計確定後に追加予定（認証方式未定のため今回はスコープ外）。

### Profile API の追加（GET / PUT / DELETE /api/v1/profile）

- `ProfilesController` を新規作成し、プロフィール取得・更新・退会の3エンドポイントを実装
- routes.rb の `resource :profile` に `show` を追加（元々 update/destroy のみ定義されていた）
- `update` の Strong Parameters は `nickname` と `target_level` のみ許可。email・password は変更不可とした（セキュリティ上、変更は別フローで行うべきため）
- `destroy` は refresh token を `update_columns` で即時 revoke してから `current_user.destroy`。User モデルに `dependent: :destroy` が設定済みのため、`word_bookmarks` と `study_session` は Cascade 削除される
- `doc/openapi.yml` に `/api/v1/profile` エンドポイントと `Profile` スキーマを追加
- `spec/requests/api/v1/profiles_spec.rb` を作成し、正常系・異常系を網羅

## 2026-04-21

### WordDays API を追加（GET /api/v1/word_days）

- JLPTレベル別のDAY一覧を返すエンドポイントを実装
- フロントエンドのDAY選択画面用。`?jlpt_level=n5` でそのレベルのDAY番号一覧を取得できる
- 各DAYの代表 `word_day_id` は `MIN(id)` で返す設計にした。DAYごとに複数のword_dayレコードが存在するため、study_session更新時に使えるidを1件だけ返す必要があった。MAX/MINどちらでもよいがMINの方が安定的

## 2026-04-19

### ブックマーク一覧 API の追加（GET /api/v1/bookmarks）

- `GET /api/v1/bookmarks`: 認証ユーザーのブックマーク済み単語一覧を返す
- `?jlpt_level=n5` クエリパラメーターで絞り込み可能。不正値は 400 を返す
- `has_many :bookmarked_words, through: :word_bookmarks` を利用し、N+1 なしで取得

**設計判断: nested route にせず最上位 resources :bookmarks に index のみ追加**
- POST/DELETE は `/api/v1/words/:word_id/bookmark` (nested) だが、一覧は word_id を必要としないため最上位が適切
- 既存 nested route に手を加えず独立させることでルーティングの影響範囲を最小化

**設計判断: bookmarked は常に true 固定**
- index アクションで返す単語は全て北マーク済みのため、動的チェック不要

### Study Session API の実装（GET/PUT /api/v1/study_session）

- `GET /api/v1/study_session`: 現在のユーザーの学習セッションを返す。セッション未作成の場合は `data: null` で 200
- `PUT /api/v1/study_session`: word_day_id を受け取り、セッションを upsert（なければ作成、あれば更新）

**設計判断: PATCH ではなく PUT を採用**
- StudySession はユーザーにつき1件のみ存在し、管理するフィールドは `word_day_id` 一つ
- 「このDAYまで学習した」という状態を上書きする upsert セマンティクスは PUT が自然
- PATCH は「一部フィールドの選択的更新」を意味するが、今回は実質全フィールドを毎回指定するため PUT が正確

**設計判断: OpenAPI 3.0 で nullable $ref に allOf を使用**
- GET レスポンスの `data` はセッション未作成時に null になりうる
- OpenAPI 3.0 では `$ref` と `nullable: true` を同じレベルに書いても `$ref` が優先され nullable が無視される
- 公式 workaround として `nullable: true` + `allOf: [$ref]` の組み合わせを採用（OpenAPI 3.1 では不要）

### eager load・Strong Parameters の追加

- `StudySession` 取得時に `includes(word_day: :word)` を追加し N+1 を解消
- `auth_controller` の `login` / `refresh` に Strong Parameters を追加（`signup_params` は既存）
- `study_sessions_controller` に `study_session_params` を追加

### Bookmarks API の実装

- `POST /api/v1/words/:word_id/bookmark` — ブックマーク追加（201）
- `DELETE /api/v1/words/:word_id/bookmark` — ブックマーク解除（200）
- nested resource として `resources :words` 配下に `resource :bookmark` を追加
  - singular resource にした理由: 1ユーザー × 1単語のブックマークは常に1件のみのため
- 重複追加は model の uniqueness バリデーションで422を返す設計
  - DB の unique index が最終防衛ラインとして機能する
- `SuccessNullResponse` スキーマを OpenAPI に追加（data/error が nullable な成功レスポンス共通定義）
- RSpec request spec 7件すべてパス（全体26件パス）

---

## 2026-04-17

### Words API の実装

- `GET /api/v1/words?jlpt_level=n5&day_number=1` — レベル・DAYフィルタで単語一覧取得
- `GET /api/v1/words/:id` — 単語詳細（最新AI例文付き）
- レスポンスにブックマーク状態 (`bookmarked: bool`) を含める設計にした
  - フロント側でブックマーク状態をキャッシュするより、取得時に一緒に返す方がシンプル
  - N+1を避けるためブックマークIDをSetで取得してメモリ内で判定
- `jlpt_level` 未指定は400、存在しないIDは404を返す
- OpenAPI schema の `ErrorResponse.data` に `nullable: true` を追加（既存の auth spec も恩恵）
- Factory: `word`, `word_day`, `word_bookmark`, `daily_story`, `ai_content` を追加

### JWT認証APIの実装

- `POST /api/v1/auth/signup` / `login` / `refresh` / `DELETE logout` の4エンドポイントを実装
- `lib/json_web_token.rb` にJWT encode/decode ユーティリティを切り出し (access: 15分 / refresh: 7日)
- refresh tokenはDB側でbcryptハッシュとして保存し、logout時にnil更新でrevoke
- `/auth/refresh` はaccess tokenの有効期限切れを許容してデコードし、user_idを取得する設計を採用
  — フロントが期限切れのtokenをそのままヘッダーに乗せてrefreshできるようにするため
- CORS: `CORS_ORIGINS` 環境変数で本番/開発を切り替え。デフォルト `http://localhost:5173`
- RSpec request spec 10件すべてパス

### DBスキーマ・Modelの実装とシードデータの投入

- 全テーブルのMigrationを作成・実行（users, words, word_days, daily_stories, daily_story_words, ai_contents, word_bookmarks, study_sessions）
- 各Modelにassociation・validationを定義
- N5〜N1のCSVファイルからシードデータを投入 — 2062単語 / 2080 word_daysエントリ
- RSpec・FactoryBot・Faker・kaminari・jwt・rack-corsをGemfileに追加
- CSVをDAY単位（20単語）で分割してword_daysに登録する設計を採用（レベル内のDAY番号はCSVの順序から自動算出）

### Rails APIプロジェクトの雛形を生成

- `rails new --api --database=postgresql` で Rails 8.1.3 の API モードプロジェクトを生成
- 不要モジュール（mailer, action-text, active-storage, cable, hotwire）をすべて除外し、軽量な API サーバーとして構成
- Dockerfile, GitHub Actions CI, CORS 初期化ファイルが自動生成済み
- DEVLOGを各リポジトリ管理に変更し、作業言語を日本語に統一
