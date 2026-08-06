# kotoba-api

[kotoba-ai](https://github.com/the-hana/kotoba-infra) の Rails API サーバー。JWT認証 + Gemini AI連携 + PostgreSQL。

関連リポジトリ: [kotoba-web](https://github.com/the-hana/kotoba-web)（React フロントエンド） / [kotoba-infra](https://github.com/the-hana/kotoba-infra)（Terraform AWSインフラ）

**Live API**: https://dlxlfjdqep5lt.cloudfront.net/api/v1

## 技術スタック

- Ruby 3.3.6 / Rails 8.1.3（API mode）
- PostgreSQL
- 認証: JWT（bcrypt でハッシュ化した refresh token を DB 保存）
- Gemini API（今日のストーリー生成・単語別例文生成）
- RSpec / FactoryBot

## アーキテクチャ

### 認証フロー

- `POST /api/v1/auth/signup` / `login` → access token（15分） + refresh token（7日）を発行
- `POST /api/v1/auth/refresh` → refresh token を bcrypt 検証し新しい access token を発行
- `DELETE /api/v1/auth/logout` → DB の refresh token を削除（revoke）

### AI パイプライン

```
EventBridge (JST 18:30) → SQS → Lambda → Webhooks::DailyStoriesController
                                                  │
                                DailyWordSelectorService → GeminiService → DailyStoryCreationService
                                                                                  │
                                                                    daily_stories / ai_contents に保存
```

本番では Lambda が EventBridge トリガー役に専念し、Gemini API 呼び出しは Rails 側で行う（[kotoba-infra](https://github.com/the-hana/kotoba-infra) 参照）。

## API エンドポイント

| Method | Path | 説明 |
|---|---|---|
| POST | `/api/v1/auth/signup` `/login` `/refresh` | 認証 |
| DELETE | `/api/v1/auth/logout` | ログアウト |
| GET | `/api/v1/words` `/words/:id` | 単語一覧・詳細 |
| POST/DELETE | `/api/v1/words/:id/bookmark` | ブックマーク追加・解除 |
| GET | `/api/v1/bookmarks` | ブックマーク一覧 |
| GET | `/api/v1/word_days` | DAY単位の単語グルーピング |
| GET/PUT | `/api/v1/study_session` | 学習進捗（streak管理） |
| GET/PUT/DELETE | `/api/v1/profile` | プロフィール |
| PUT | `/api/v1/profile/password` | パスワード変更 |
| GET | `/api/v1/daily_story` | 今日のストーリー取得 |
| POST | `/webhooks/daily_story` | Lambda からのストーリー生成トリガー（`X-Internal-Token` 認証） |

詳細な仕様は [`doc/openapi.yml`](doc/openapi.yml) を参照。全レスポンスは `{ success, data, error }` 形式で統一。

## セットアップ

### 前提条件

- Ruby 3.3.6
- PostgreSQL
- Gemini API キー

### 実行

```bash
bundle install
bundle exec rails db:migrate
bundle exec rails db:seed
bundle exec rails server
```

### テスト

```bash
bundle exec rspec
```

### 環境変数

| 変数名 | 説明 |
|---|---|
| `DATABASE_URL` | PostgreSQL 接続文字列 |
| `RAILS_MASTER_KEY` | `config/credentials.yml.enc` の復号キー |
| `GEMINI_API_KEY` | Gemini API キー |
| `INTERNAL_API_KEY` | Lambda → Rails webhook 認証キー |
| `CORS_ORIGINS` | 許可するフロントエンドオリジン |

## コーディング規約

- 全レスポンス: `{ success: true/false, data: ..., error: ... }` に統一
- Strong Parameters: body params を受け取る action には必ず `_params` メソッドを定義
- N+1 対策: `includes` / `eager_load` を必須化
- Raw SQL 禁止、ActiveRecord のみ使用
