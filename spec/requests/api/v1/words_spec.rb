require "rails_helper"

RSpec.describe "Api::V1::Words", type: :request do
  # テスト用JWTトークンを生成するヘルパー
  def auth_headers(user)
    token = JsonWebToken.encode_access_token(user_id: user.id)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/words" do
    context "正常系: jlpt_level=n5" do
      before do
        user = create(:user)
        word1 = create(:word, jlpt_level: "n5")
        word2 = create(:word, jlpt_level: "n5")
        create(:word, jlpt_level: "n4")
        create(:word_day, word: word1, day_number: 1)
        create(:word_day, word: word2, day_number: 1)
        # word1をブックマーク済み
        create(:word_bookmark, user: user, word: word1)

        get "/api/v1/words", params: { jlpt_level: "n5" }, headers: auth_headers(user)
      end

      it "n5の単語のみ返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(response.parsed_body["data"].length).to eq 2
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        levels = response.parsed_body["data"].map { |w| w["jlpt_level"] }.uniq
        expect(levels).to eq ["n5"]
      end
    end

    context "正常系: day_numberフィルター" do
      before do
        user = create(:user)
        word_day1 = create(:word_day, word: create(:word, jlpt_level: "n5"), day_number: 1)
        word_day2 = create(:word_day, word: create(:word, jlpt_level: "n5"), day_number: 2)

        get "/api/v1/words", params: { jlpt_level: "n5", day_number: 1 }, headers: auth_headers(user)
      end

      it "DAY1の単語のみ返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(response.parsed_body["data"].length).to eq 1
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "正常系: ブックマーク状態が反映されること" do
      before do
        user = create(:user)
        word = create(:word, jlpt_level: "n5")
        create(:word_bookmark, user: user, word: word)

        get "/api/v1/words", params: { jlpt_level: "n5" }, headers: auth_headers(user)
      end

      it "ブックマーク済み単語はbookmarked: trueを返す" do
        expect(response.status).to eq 200
        expect(response.parsed_body["data"].first["bookmarked"]).to be true
      end
    end

    context "jlpt_level未指定の場合" do
      before do
        user = create(:user)
        get "/api/v1/words", headers: auth_headers(user)
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
        get "/api/v1/words", params: { jlpt_level: "n5" }
      end

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  describe "GET /api/v1/words/:id" do
    context "正常系: AI例文あり" do
      before do
        user = create(:user)
        word = create(:word, jlpt_level: "n5")
        create(:ai_content, word: word)

        get "/api/v1/words/#{word.id}", headers: auth_headers(user)
      end

      it "AI例文付きの単語詳細を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        ai = response.parsed_body["data"]["ai_content"]
        expect(ai["example_sentence"]).to be_present
        expect(ai["example_sentence_korean"]).to be_present
      end
    end

    context "正常系: AI例文なし" do
      before do
        user = create(:user)
        word = create(:word, jlpt_level: "n5")

        get "/api/v1/words/#{word.id}", headers: auth_headers(user)
      end

      it "ai_content: nullを返す" do
        expect(response.status).to eq 200
        assert_response_schema_confirm(200)
        expect(response.parsed_body["data"]["ai_content"]).to be_nil
      end
    end

    context "存在しないIDの場合" do
      before do
        user = create(:user)
        get "/api/v1/words/99999", headers: auth_headers(user)
      end

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

    context "Authorizationヘッダーなしの場合" do
      before do
        word = create(:word)
        get "/api/v1/words/#{word.id}"
      end

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
