# kotoba-api

Rails APIサーバー。JWT認証 + Gemini連携 + PostgreSQL。

## 스택

Ruby on Rails · PostgreSQL · bcrypt · JWT · Gemini API · RSpec · Docker

## 인증 흐름

- `POST /api/auth/signup` → 유저 생성, 토큰 쌍 반환
- `POST /api/auth/login` → 비밀번호 검증, 토큰 쌍 반환
- `POST /api/auth/refresh` → refresh token 해시 검증, 새 access token 발급
- `POST /api/auth/logout` → DB에서 refresh token 삭제 (revoke)
- Access token: 15분 / Refresh token: 7일, DB에 bcrypt 해시로 저장

## DB 규칙

- 기존 migration 파일 수정 금지 — 항상 새로 생성
- Raw SQL 금지 — ActiveRecord만 사용
- N+1 쿼리 금지 — `includes` / `eager_load` 사용
- 시드 데이터: JLPT N5–N1 공개 데이터셋 CSV

## API 규칙

- 모든 응답: `{ success: true/false, data: ..., error: ... }`
- 인증 필요 엔드포인트: `Authorization: Bearer <token>` 헤더
- 페이지네이션: `?page=1&per=20` (Kaminari)

## 주요 모델

User email, nickname, password_digest, refresh_token (hash),
refresh_token_expires_at, target_level
Word japanese, korean, hiragana, jlpt_level
WordDay word_id, day_number
AiContent word_id, daily_story_id, example_sentence, example_sentence_korean
DailyStory story_date (unique), content, content_korean
DailyStoryWord daily_story_id + word_id (unique 조합)
WordBookmark user_id + word_id (unique 조합) — 추가: INSERT, 해제: DELETE
StudySession user_id (unique), word_day_id (FK → word_days.id), updated_at (연속 학습일 기준)

## Gemini 연동

- 단어별 예문: 요청 시마다 생성, 캐싱 없음 (동일 단어도 매번 새로 생성)
- 오늘의 스토리: 단어 10개 → 일본어 스토리 + 한국어 번역
- 프로덕션에서는 Lambda가 트리거 — Rails에서 직접 Gemini 호출 금지

## DEVLOG 규칙

- 커밋 시 이 repo의 `DEVLOG.md` 상단에 작업 내용을 추가할 것
- **작성 언어: 日本語** (한국어 사용 금지)
- 사소한 변경은 생략 가능. 설계 결정·트레이드오프가 있는 작업은 반드시 기록.

형식:
```
## YYYY-MM-DD

### <作業タイトル>

- 何をしたか
- なぜしたか（設計判断・トレードオフがあれば必ず記録）
```

## 테스트

- 모든 새 기능에 RSpec 테스트 필수
- 실행: `bundle exec rspec`
- 테스트 데이터: Factory Bot 사용
