class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words do |t|
      t.string :japanese, null: false
      t.string :hiragana, null: false
      t.string :korean, null: false
      t.string :jlpt_level, null: false

      t.timestamps
    end

    add_index :words, :jlpt_level
  end
end
