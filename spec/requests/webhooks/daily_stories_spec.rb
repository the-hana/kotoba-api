require "rails_helper"

RSpec.describe "Webhooks::DailyStories", type: :request do
  let(:internal_token) { "test_secret_key" }
  let(:internal_headers) { { "X-Internal-Token" => internal_token, "Content-Type" => "application/json" } }

  before do
    allow(ENV).to receive(:fetch).with("INTERNAL_API_KEY").and_return(internal_token)
  end

  def stub_services(words)
    gemini_result = {
      story:        "テストストーリーです。",
      story_korean: "테스트 스토리입니다.",
      words: words.map do |w|
        { word_id: w.id, example_sentence: "例文です。", example_sentence_korean: "예문입니다。" }
      end
    }
    allow(DailyWordSelectorService).to receive(:call).and_return(words)
    allow(GeminiService).to receive(:call).and_return(gemini_result)
  end

  describe "POST /webhooks/daily_story" do
    context "正常系: リクエストが来たらGeminiを呼び出してDailyStoryを作成する" do
      before do
        words = create_list(:word, 10, jlpt_level: "n5")
        stub_services(words)
        post "/webhooks/daily_story", headers: internal_headers
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
        expect(response.parsed_body["data"]["story_date"]).to eq Date.current.to_s
      end
    end

    context "冪等性: 同じ日に2回リクエストした場合" do
      before do
        words = create_list(:word, 10, jlpt_level: "n5")
        stub_services(words)
        post "/webhooks/daily_story", headers: internal_headers
        post "/webhooks/daily_story", headers: internal_headers
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

    context "異常系: Gemini APIがエラーを返した場合" do
      before do
        words = create_list(:word, 10, jlpt_level: "n5")
        allow(DailyWordSelectorService).to receive(:call).and_return(words)
        allow(GeminiService).to receive(:call).and_raise(RuntimeError, "Gemini API error: 500")
        post "/webhooks/daily_story", headers: internal_headers
      end

      it "500を返しDBに保存しない" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 500
        # 2. DBのアサーション
        expect(DailyStory.count).to eq 0
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "401: X-Internal-Token がない場合" do
      before do
        post "/webhooks/daily_story", headers: { "Content-Type" => "application/json" }
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
             headers: internal_headers.merge("X-Internal-Token" => "wrong_token")
      end

      it "401を返す" do
        expect(response.status).to eq 401
        expect(response.parsed_body["success"]).to be false
      end
    end
  end
end
