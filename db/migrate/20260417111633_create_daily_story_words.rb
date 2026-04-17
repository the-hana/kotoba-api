class CreateDailyStoryWords < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_story_words do |t|
      t.references :daily_story, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true

      t.timestamps
    end

    add_index :daily_story_words, [ :daily_story_id, :word_id ], unique: true
  end
end
