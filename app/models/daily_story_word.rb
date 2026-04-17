class DailyStoryWord < ApplicationRecord
  belongs_to :daily_story
  belongs_to :word

  validates :word_id, uniqueness: { scope: :daily_story_id }
end
