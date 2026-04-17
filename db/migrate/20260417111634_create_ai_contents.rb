class CreateAiContents < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_contents do |t|
      t.references :word, null: false, foreign_key: true
      t.references :daily_story, null: false, foreign_key: true
      t.text :example_sentence, null: false
      t.text :example_sentence_korean, null: false

      t.timestamps
    end
  end
end
