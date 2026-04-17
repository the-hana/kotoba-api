class DailyStory < ApplicationRecord
  has_many :daily_story_words, dependent: :destroy
  has_many :words, through: :daily_story_words
  has_many :ai_contents, dependent: :destroy

  validates :story_date, presence: true, uniqueness: true
  validates :content, presence: true
  validates :content_korean, presence: true
end
