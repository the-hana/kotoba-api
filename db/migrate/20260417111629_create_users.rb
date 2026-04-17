class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :nickname, null: false
      t.string :password_digest, null: false
      t.string :refresh_token
      t.datetime :refresh_token_expires_at
      t.string :target_level, null: false, default: "n5"

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
