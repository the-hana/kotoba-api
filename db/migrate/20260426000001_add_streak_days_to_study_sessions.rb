class AddStreakDaysToStudySessions < ActiveRecord::Migration[8.1]
  def change
    add_column :study_sessions, :streak_days, :integer, null: false, default: 1
  end
end
