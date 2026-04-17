# DEVLOG — kotoba-api

コミットごとに作業内容を記録。最新のエントリが上。
設計判断・トレードオフを含む作業は必ず記録。些細な修正は省略可。

---

## 2026-04-17

### Rails APIプロジェクトの雛形を生成

- `rails new --api --database=postgresql` で Rails 8.1.3 の API モードプロジェクトを生成
- 不要モジュール（mailer, action-text, active-storage, cable, hotwire）をすべて除外し、軽量な API サーバーとして構成
- Dockerfile, GitHub Actions CI, CORS 初期化ファイルが自動生成済み
- DEVLOGを各リポジトリ管理に変更し、作業言語を日本語に統一
