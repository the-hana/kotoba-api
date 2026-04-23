require "rails_helper"

RSpec.describe "Webhooks::DailyStories", type: :request do
  let(:internal_token) { "test_secret_key" }
  let(:internal_headers) { { "X-Internal-Token" => internal_token, "Content-Type" => "application/json" } }

  before do
    allow(ENV).to receive(:fetch).with("INTERNAL_API_KEY").and_return(internal_token)
  end

  def story_payload(words)
    {
      story_date: Date.today.to_s,
      content: "テストストーリーです。",
      content_korean: "테스트 스토리입니다.",
      words: words.map do |w|
        { word_id: w.id, example_sentence: "例文です。", example_sentence_korean: "예문입니다." }
      end
    }.to_json
  end

  describe "POST /webhooks/daily_story" do
    context "正常系: 有効なリクエストの場合" do
      before do
        words = create_list(:word, 10, jlpt_level: "n5")
        post "/webhooks/daily_story", params: story_payload(words), headers: internal_headers
      end

      it "201を返し、DailyStory / DailyStoryWord / AiContent を作成する" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 201
        # 2. DBのアサーション
        expect(DailyStory.count).to eq 1
        expect(DailyStoryWord.count).to eq 10
        expect(AiContent.count).to eq 10
        # 3. 構造のアサーション
        assert_response_schema_confirm(201)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]["story_date"]).to eq Date.today.to_s
      end
    end

    context "冪等性: 同じ story_date で2回リクエストした場合" do
      before do
        words = create_list(:word, 10, jlpt_level: "n5")
        payload = story_payload(words)
        post "/webhooks/daily_story", params: payload, headers: internal_headers
        post "/webhooks/daily_story", params: payload, headers: internal_headers
      end

      it "2回目は200を返し、DailyStoryは1件のみ" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(DailyStory.count).to eq 1
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
      end
    end

    context "401: X-Internal-Token がない場合" do
      before do
        post "/webhooks/daily_story",
             params: { story_date: Date.today.to_s }.to_json,
             headers: { "Content-Type" => "application/json" }
      end

      it "401を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 401
        # 3. 構造のアサーション
        assert_response_schema_confirm(401)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "401: X-Internal-Token が不正な場合" do
      before do
        post "/webhooks/daily_story",
             params: { story_date: Date.today.to_s }.to_json,
             headers: internal_headers.merge("X-Internal-Token" => "wrong_token")
      end

      it "401を返す" do
        expect(response.status).to eq 401
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "422: words が10個未満の場合" do
      before do
        words = create_list(:word, 9, jlpt_level: "n5")
        post "/webhooks/daily_story", params: story_payload(words), headers: internal_headers
      end

      it "422を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 422
        # 3. 構造のアサーション
        assert_response_schema_confirm(422)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "422: words キーがない場合" do
      before do
        payload = { story_date: Date.today.to_s, content: "テスト", content_korean: "테스트" }.to_json
        post "/webhooks/daily_story", params: payload, headers: internal_headers
      end

      it "422を返す" do
        expect(response.status).to eq 422
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
