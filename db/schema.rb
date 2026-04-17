# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_17_111636) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_contents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_story_id", null: false
    t.text "example_sentence", null: false
    t.text "example_sentence_korean", null: false
    t.datetime "updated_at", null: false
    t.bigint "word_id", null: false
    t.index ["daily_story_id"], name: "index_ai_contents_on_daily_story_id"
    t.index ["word_id"], name: "index_ai_contents_on_word_id"
  end

  create_table "daily_stories", force: :cascade do |t|
    t.text "content", null: false
    t.text "content_korean", null: false
    t.datetime "created_at", null: false
    t.date "story_date", null: false
    t.datetime "updated_at", null: false
    t.index ["story_date"], name: "index_daily_stories_on_story_date", unique: true
  end

  create_table "daily_story_words", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_story_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "word_id", null: false
    t.index ["daily_story_id", "word_id"], name: "index_daily_story_words_on_daily_story_id_and_word_id", unique: true
    t.index ["daily_story_id"], name: "index_daily_story_words_on_daily_story_id"
    t.index ["word_id"], name: "index_daily_story_words_on_word_id"
  end

  create_table "study_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "word_day_id", null: false
    t.index ["user_id"], name: "index_study_sessions_on_user_id", unique: true
    t.index ["word_day_id"], name: "index_study_sessions_on_word_day_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "nickname", null: false
    t.string "password_digest", null: false
    t.string "refresh_token"
    t.datetime "refresh_token_expires_at"
    t.string "target_level", default: "n5", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "word_bookmarks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "word_id", null: false
    t.index ["user_id", "word_id"], name: "index_word_bookmarks_on_user_id_and_word_id", unique: true
    t.index ["user_id"], name: "index_word_bookmarks_on_user_id"
    t.index ["word_id"], name: "index_word_bookmarks_on_word_id"
  end

  create_table "word_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_number", null: false
    t.datetime "updated_at", null: false
    t.bigint "word_id", null: false
    t.index ["word_id", "day_number"], name: "index_word_days_on_word_id_and_day_number"
    t.index ["word_id"], name: "index_word_days_on_word_id"
  end

  create_table "words", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hiragana", null: false
    t.string "japanese", null: false
    t.string "jlpt_level", null: false
    t.string "korean", null: false
    t.datetime "updated_at", null: false
    t.index ["jlpt_level"], name: "index_words_on_jlpt_level"
  end

  add_foreign_key "ai_contents", "daily_stories"
  add_foreign_key "ai_contents", "words"
  add_foreign_key "daily_story_words", "daily_stories"
  add_foreign_key "daily_story_words", "words"
  add_foreign_key "study_sessions", "users"
  add_foreign_key "study_sessions", "word_days"
  add_foreign_key "word_bookmarks", "users"
  add_foreign_key "word_bookmarks", "words"
  add_foreign_key "word_days", "words"
end
