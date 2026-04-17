class WordDay < ApplicationRecord
  belongs_to :word
  has_many :study_sessions, dependent: :nullify

  validates :day_number, presence: true, numericality: { greater_than: 0 }
end
