class CreateDailyStories < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_stories do |t|
      t.date :story_date, null: false
      t.text :content, null: false
      t.text :content_korean, null: false

      t.timestamps
    end

    add_index :daily_stories, :story_date, unique: true
  end
end
