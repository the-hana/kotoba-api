require "rails_helper"

RSpec.describe "Api::V1::StudySessions", type: :request do
  describe "GET /api/v1/study_session" do
    context "正常系: セッションが存在する場合" do
      let(:user) { create(:user) }
      let(:word_day) { create(:word_day) }

      before do
        create(:study_session, user: user, word_day: word_day)
        get "/api/v1/study_session", headers: auth_headers(user)
      end

      it "200を返しセッション情報を含む" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        data = response.parsed_body["data"]
        expect(data["word_day_id"]).to eq word_day.id
        expect(data["jlpt_level"]).to eq word_day.word.jlpt_level
        expect(data["day_number"]).to eq word_day.day_number
        expect(data["updated_at"]).to be_present
      end
    end

    context "正常系: セッションが存在しない場合" do
      let(:user) { create(:user) }

      before { get "/api/v1/study_session", headers: auth_headers(user) }

      it "200を返しdataがnull" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]).to be_nil
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      before { get "/api/v1/study_session" }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "PUT /api/v1/study_session" do
    context "正常系: セッション新規作成" do
      let(:user) { create(:user) }
      let(:word_day) { create(:word_day) }

      before { put "/api/v1/study_session", params: { word_day_id: word_day.id }, headers: auth_headers(user) }

      it "200を返しDBにレコードが作成される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(StudySession.exists?(user: user, word_day: word_day)).to be true
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        data = response.parsed_body["data"]
        expect(data["word_day_id"]).to eq word_day.id
        expect(data["jlpt_level"]).to eq word_day.word.jlpt_level
        expect(data["day_number"]).to eq word_day.day_number
      end
    end

    context "正常系: セッション更新（word_dayを変更）" do
      let(:user) { create(:user) }
      let(:word) { create(:word) }
      let(:word_day_1) { create(:word_day, word: word, day_number: 1) }
      let(:word_day_2) { create(:word_day, word: word, day_number: 2) }

      before do
        create(:study_session, user: user, word_day: word_day_1)
        put "/api/v1/study_session", params: { word_day_id: word_day_2.id }, headers: auth_headers(user)
      end

      it "200を返しDBのword_day_idが更新される" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(user.reload.study_session.word_day_id).to eq word_day_2.id
        expect(StudySession.count).to eq 1
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["data"]["word_day_id"]).to eq word_day_2.id
        expect(response.parsed_body["data"]["day_number"]).to eq 2
      end
    end

    context "異常系: 存在しない word_day_id" do
      let(:user) { create(:user) }

      before { put "/api/v1/study_session", params: { word_day_id: 99999 }, headers: auth_headers(user) }

      it "404を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 404
        # 3. 構造のアサーション
        assert_response_schema_confirm(404)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "異常系: Authorizationヘッダーなし" do
      let(:word_day) { create(:word_day) }

      before { put "/api/v1/study_session", params: { word_day_id: word_day.id } }

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
