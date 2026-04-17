class CreateWordBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :word_bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true

      t.timestamps
    end

    add_index :word_bookmarks, [ :user_id, :word_id ], unique: true
  end
end
