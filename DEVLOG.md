# DEVLOG — kotoba-api

コミットごとに作業内容を記録。最新のエントリが上。
設計判断・トレードオフを含む作業は必ず記録。些細な修正は省略可。

---

## 2026-04-17

### JWT認証APIの実装

- `POST /api/v1/auth/signup` / `login` / `refresh` / `DELETE logout` の4エンドポイントを実装
- `lib/json_web_token.rb` にJWT encode/decode ユーティリティを切り出し (access: 15分 / refresh: 7日)
- refresh tokenはDB側でbcryptハッシュとして保存し、logout時にnil更新でrevoke
- `/auth/refresh` はaccess tokenの有効期限切れを許容してデコードし、user_idを取得する設計を採用
  — フロントが期限切れのtokenをそのままヘッダーに乗せてrefreshできるようにするため
- CORS: `CORS_ORIGINS` 環境変数で本番/開発を切り替え。デフォルト `http://localhost:5173`
- RSpec request spec 10件すべてパス

---

## 2026-04-17

### DBスキーマ・Modelの実装とシードデータの投入

- 全テーブルのMigrationを作成・実行（users, words, word_days, daily_stories, daily_story_words, ai_contents, word_bookmarks, study_sessions）
- 各Modelにassociation・validationを定義
- N5〜N1のCSVファイルからシードデータを投入 — 2062単語 / 2080 word_daysエントリ
- RSpec・FactoryBot・Faker・kaminari・jwt・rack-corsをGemfileに追加
- CSVをDAY単位（20単語）で分割してword_daysに登録する設計を採用（レベル内のDAY番号はCSVの順序から自動算出）

---

## 2026-04-17

### Rails APIプロジェクトの雛形を生成

- `rails new --api --database=postgresql` で Rails 8.1.3 の API モードプロジェクトを生成
- 不要モジュール（mailer, action-text, active-storage, cable, hotwire）をすべて除外し、軽量な API サーバーとして構成
- Dockerfile, GitHub Actions CI, CORS 初期化ファイルが自動生成済み
- DEVLOGを各リポジトリ管理に変更し、作業言語を日本語に統一
