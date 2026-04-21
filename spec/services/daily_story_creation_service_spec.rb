require "rails_helper"

RSpec.describe DailyStoryCreationService do
  def build_word_data(words)
    words.map do |w|
      {
        word_id:                 w.id,
        example_sentence:        "#{w.japanese}の例文です。",
        example_sentence_korean: "#{w.korean}의 예문입니다."
      }
    end
  end

  describe ".call" do
    context "正常系: 単語10個" do
      before do
        @words = create_list(:word, 10, jlpt_level: "n5")
        @params = {
          story_date:     Date.today,
          content:        "テストストーリー",
          content_korean: "테스트 스토리",
          words:          build_word_data(@words)
        }
      end

      it "DailyStory + DailyStoryWord×10 + AiContent×10 を作成する" do
        expect {
          described_class.call(@params)
        }.to change(DailyStory, :count).by(1)
          .and change(DailyStoryWord, :count).by(10)
          .and change(AiContent, :count).by(10)
      end

      it "作成したDailyStoryを返す" do
        result = described_class.call(@params)
        expect(result).to be_a(DailyStory)
        expect(result.story_date).to eq Date.today
        expect(result.content).to eq "テストストーリー"
      end
    end

    context "異常系: 単語が9個の場合" do
      before do
        @words = create_list(:word, 9, jlpt_level: "n5")
        @params = {
          story_date:     Date.today,
          content:        "テストストーリー",
          content_korean: "테스트 스토리",
          words:          build_word_data(@words)
        }
      end

      it "ArgumentErrorを発生させる" do
        expect {
          described_class.call(@params)
        }.to raise_error(ArgumentError, "単語は10個必要です")
      end

      it "DBにデータが作成されない" do
        expect {
          described_class.call(@params) rescue nil
        }.not_to change(DailyStory, :count)
      end
    end

    context "異常系: story_dateが重複する場合" do
      before do
        @words = create_list(:word, 10, jlpt_level: "n5")
        create(:daily_story, story_date: Date.today)
        @params = {
          story_date:     Date.today,
          content:        "重複ストーリー",
          content_korean: "중복 스토리",
          words:          build_word_data(@words)
        }
      end

      it "ActiveRecord::RecordInvalidを発生させる" do
        expect {
          described_class.call(@params)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "トランザクションがrollbackされDailyStoryWordが作成されない" do
        expect {
          described_class.call(@params) rescue nil
        }.not_to change(DailyStoryWord, :count)
      end
    end
  end
end
