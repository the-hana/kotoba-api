class StudySession < ApplicationRecord
  belongs_to :user
  belongs_to :word_day

  validates :user_id, uniqueness: true

  before_save :calculate_streak, if: :persisted?

  private

  def calculate_streak
    previous_date = updated_at.to_date
    today = Time.current.to_date

    self.streak_days = case previous_date
    when today     then streak_days
    when today - 1 then streak_days + 1
    else                1
    end
  end
end
