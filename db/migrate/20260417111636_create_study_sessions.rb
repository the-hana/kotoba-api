class CreateStudySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :study_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :word_day, null: false, foreign_key: true

      t.timestamps
    end
  end
end
