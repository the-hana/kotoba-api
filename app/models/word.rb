class Word < ApplicationRecord
  has_many :word_days, dependent: :destroy
  has_many :word_bookmarks, dependent: :destroy
  has_many :daily_story_words, dependent: :destroy
  has_many :daily_stories, through: :daily_story_words
  has_many :ai_contents, dependent: :destroy

  JLPT_LEVELS = %w[n5 n4 n3 n2 n1].freeze

  validates :japanese, presence: true
  validates :hiragana, presence: true
  validates :korean, presence: true
  validates :jlpt_level, inclusion: { in: JLPT_LEVELS }
end
