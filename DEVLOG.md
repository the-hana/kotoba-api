# DEVLOG — kotoba-api

コミットごとに作業内容を記録。最新のエントリが上。
設計判断・トレードオフを含む作業は必ず記録。些細な修正は省略可。

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
