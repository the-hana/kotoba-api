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
          story_date:     Date.current,
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

      it "[story, true] を返す" do
        story, created = described_class.call(@params)
        expect(story).to be_a(DailyStory)
        expect(story.story_date).to eq Date.current
        expect(story.content).to eq "テストストーリー"
        expect(created).to be true
      end
    end

    context "異常系: 単語が9個の場合" do
      before do
        @words = create_list(:word, 9, jlpt_level: "n5")
        @params = {
          story_date:     Date.current,
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

    context "異常系: story_date が無効な場合" do
      before do
        @words = create_list(:word, 10, jlpt_level: "n5")
      end

      it "story_date が空の場合 ArgumentError を発生させる" do
        params = { story_date: nil, content: "テスト", content_korean: "테스트", words: build_word_data(@words) }
        expect { described_class.call(params) }.to raise_error(ArgumentError, /story_date が無効です/)
      end

      it "story_date が不正な文字列の場合 ArgumentError を発生させる" do
        params = { story_date: "not-a-date", content: "テスト", content_korean: "테스트", words: build_word_data(@words) }
        expect { described_class.call(params) }.to raise_error(ArgumentError, /story_date が無効です/)
      end
    end

    context "異常系: word_id が重複する場合" do
      before do
        @words = create_list(:word, 10, jlpt_level: "n5")
        duplicated = build_word_data(@words)
        duplicated[0] = duplicated[1].dup
        @params = { story_date: Date.current, content: "テスト", content_korean: "테스트", words: duplicated }
      end

      it "ArgumentError を発生させる" do
        expect { described_class.call(@params) }.to raise_error(ArgumentError, /word_id に重複があります/)
      end

      it "DBにデータが作成されない" do
        expect { described_class.call(@params) rescue nil }.not_to change(DailyStory, :count)
      end
    end

    context "冪等性: story_dateが重複する場合" do
      before do
        @words = create_list(:word, 10, jlpt_level: "n5")
        @existing = create(:daily_story, story_date: Date.current)
        @params = {
          story_date:     Date.current,
          content:        "重複ストーリー",
          content_korean: "중복 스토리",
          words:          build_word_data(@words)
        }
      end

      it "[existing_story, false] を返す" do
        story, created = described_class.call(@params)
        expect(story.id).to eq @existing.id
        expect(created).to be false
      end

      it "DailyStoryWordが追加作成されない" do
        expect {
          described_class.call(@params)
        }.not_to change(DailyStoryWord, :count)
      end
    end
  end
end
