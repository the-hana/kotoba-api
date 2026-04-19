require_relative "seeds/words_data"

# WORDS_SEED_DATAをWordsとWordDaysに登録する
# DAY単位（20単語）でword_daysを構成する
# 冪等 — 何度実行しても重複しない

WORDS_PER_DAY = 20

puts "シードデータの投入を開始します..."

current_level = nil
level_index = 0

WORDS_SEED_DATA.each do |data|
  if data[:jlpt_level] != current_level
    current_level = data[:jlpt_level]
    level_index = 0
    puts "  [#{current_level.upcase}] 登録中..."
  end

  word = Word.find_or_create_by!(
    japanese: data[:japanese],
    jlpt_level: data[:jlpt_level]
  ) do |w|
    w.hiragana = data[:hiragana]
    w.korean = data[:korean]
  end

  day_number = (level_index / WORDS_PER_DAY) + 1
  WordDay.find_or_create_by!(word: word, day_number: day_number)

  level_index += 1
end

puts ""
puts "シード完了: #{Word.count}単語 / #{WordDay.count}DAYエントリ"

# 開発用テストユーザー
if Rails.env.development?
  User.find_or_create_by!(email: "test@example.com") do |u|
    u.nickname = "テストユーザー"
    u.password = "password123"
    u.password_confirmation = "password123"
    u.target_level = "n5"
  end
  puts "開発用ユーザー作成: test@example.com / password123"
end
