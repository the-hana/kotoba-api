class CreateWordDays < ActiveRecord::Migration[8.1]
  def change
    create_table :word_days do |t|
      t.references :word, null: false, foreign_key: true
      t.integer :day_number, null: false

      t.timestamps
    end

    add_index :word_days, [ :word_id, :day_number ]
  end
end
