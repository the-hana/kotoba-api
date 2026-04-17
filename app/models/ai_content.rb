class AiContent < ApplicationRecord
  belongs_to :word
  belongs_to :daily_story

  validates :example_sentence, presence: true
  validates :example_sentence_korean, presence: true
end
