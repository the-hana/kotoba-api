class StudySession < ApplicationRecord
  belongs_to :user
  belongs_to :word_day

  validates :user_id, uniqueness: true
end
