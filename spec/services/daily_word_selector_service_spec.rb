require "rails_helper"

RSpec.describe DailyWordSelectorService do
  describe ".call" do
    context "未使用単語が10個以上ある場合" do
      before do
        create(:user, target_level: "n5")
        create_list(:word, 12, jlpt_level: "n5")
      end

      it "未使用単語のみ10個返す" do
        result = described_class.call
        expect(result.size).to eq 10
        used_ids = DailyStoryWord.pluck(:word_id)
        expect(result.map(&:id)).to all(satisfy { |id| used_ids.exclude?(id) })
      end
    end

    context "未使用単語が5個しかない場合" do
      before do
        create(:user, target_level: "n5")
        story = create(:daily_story)
        # 使用済み: 10個
        10.times do
          word = create(:word, jlpt_level: "n5")
          create(:daily_story_word, daily_story: story, word: word)
        end
        # 未使用: 5個
        create_list(:word, 5, jlpt_level: "n5")
      end

      it "未使用5個 + 使用済み5個で合計10個返す" do
        result = described_class.call
        expect(result.size).to eq 10
      end
    end

    context "ユーザーが複数いる場合" do
      before do
        # n4ユーザーが多い
        create_list(:user, 3, target_level: "n4")
        create_list(:user, 1, target_level: "n5")
        create_list(:word, 10, jlpt_level: "n4")
        create_list(:word, 10, jlpt_level: "n5")
      end

      it "最多target_levelの単語を返す" do
        result = described_class.call
        expect(result.map(&:jlpt_level).uniq).to eq [ "n4" ]
      end
    end

    context "ユーザーが0人の場合" do
      before do
        create_list(:word, 10, jlpt_level: "n5")
      end

      it "n5フォールバックで単語を返す" do
        result = described_class.call
        expect(result.map(&:jlpt_level).uniq).to eq [ "n5" ]
      end
    end
  end
end
