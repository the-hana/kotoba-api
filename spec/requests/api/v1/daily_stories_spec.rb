require "rails_helper"

RSpec.describe "Api::V1::DailyStories", type: :request do
  describe "GET /api/v1/daily_story" do
    context "正常系: 最新ストーリーが存在する場合" do
      before do
        user  = create(:user)
        words = create_list(:word, 10, jlpt_level: "n5")
        story = create(:daily_story, story_date: Date.today)
        words.each do |w|
          create(:daily_story_word, daily_story: story, word: w)
          create(:ai_content, daily_story: story, word: w)
        end

        get "/api/v1/daily_story", headers: auth_headers(user)
      end

      it "最新ストーリーを返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 200
        # 2. DBのアサーション
        expect(response.parsed_body["data"]["words"].length).to eq 10
        # 3. 構造のアサーション
        assert_response_schema_confirm(200)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["data"]["story_date"]).to eq Date.today.to_s
      end
    end

    context "正常系: 複数ストーリーがある場合、最新を返す" do
      before do
        user       = create(:user)
        old_story  = create(:daily_story, story_date: Date.today - 1)
        new_story  = create(:daily_story, story_date: Date.today)
        words      = create_list(:word, 10, jlpt_level: "n5")
        words.each do |w|
          create(:daily_story_word, daily_story: new_story, word: w)
          create(:ai_content, daily_story: new_story, word: w)
        end

        get "/api/v1/daily_story", headers: auth_headers(user)
      end

      it "最新日付のストーリーを返す" do
        expect(response.status).to eq 200
        expect(response.parsed_body["data"]["story_date"]).to eq Date.today.to_s
      end
    end

    context "404: ストーリーが存在しない場合" do
      before do
        user = create(:user)
        get "/api/v1/daily_story", headers: auth_headers(user)
      end

      it "404を返す" do
        # 1. HTTPステータスのアサーション
        expect(response.status).to eq 404
        # 3. 構造のアサーション
        assert_response_schema_confirm(404)
        # 4. 値のアサーション
        expect(response.parsed_body["success"]).to be false
      end
    end

    context "401: 未認証の場合" do
      before do
        get "/api/v1/daily_story"
      end

      it "401を返す" do
        expect(response.status).to eq 401
        assert_response_schema_confirm(401)
      end
    end
  end
end
