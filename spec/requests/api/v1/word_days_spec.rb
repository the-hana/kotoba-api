require "rails_helper"

RSpec.describe "Api::V1::WordDays", type: :request do
  describe "GET /api/v1/word_days" do
    context "正常系: jlpt_level=n5" do
      before do
        user = create(:user)
        @first_word_day = create(:word_day, word: create(:word, jlpt_level: "n5"), day_number: 1)
        create(:word_day, word: create(:word, jlpt_level: "n5"), day_number: 1)
        create(:word_day, word: create(:word, jlpt_level: "n5"), day_number: 2)

        get "/api/v1/word_days", params: { jlpt_level: "n5" }, headers: auth_headers(user)
      end

      it "n5のDAY一覧を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(response.parsed_body["data"].length).to eq 2
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        day_numbers = response.parsed_body["data"].map { |d| d["day_number"] }
        expect(day_numbers).to eq [ 1, 2 ]
        expect(response.parsed_body["data"].first["id"]).to eq @first_word_day.id
      end
    end

    context "正常系: 他レベルのword_dayは含まれないこと" do
      before do
        user = create(:user)
        @n5_word_day = create(:word_day, word: create(:word, jlpt_level: "n5"), day_number: 1)
        create(:word_day, word: create(:word, jlpt_level: "n4"), day_number: 1)

        get "/api/v1/word_days", params: { jlpt_level: "n5" }, headers: auth_headers(user)
      end

      it "n5のDAYのみ返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(response.parsed_body["data"].length).to eq 1
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["data"].first["day_number"]).to eq 1
        expect(response.parsed_body["data"].first["id"]).to eq @n5_word_day.id
      end
    end

    context "jlpt_level未指定の場合" do
      before do
        user = create(:user)
        get "/api/v1/word_days", headers: auth_headers(user)
      end

      it "400を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 400
        # 3. 構造のアサーション
        assert_response_schema_confirm(400)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "Authorizationヘッダーなしの場合" do
      before do
        get "/api/v1/word_days", params: { jlpt_level: "n5" }
      end

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
