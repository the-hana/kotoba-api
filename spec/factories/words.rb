FactoryBot.define do
  factory :word do
    sequence(:japanese) { |n| "単語#{n}" }
    sequence(:hiragana) { |n| "たんご#{n}" }
    sequence(:korean) { |n| "단어#{n}" }
    jlpt_level { "n5" }
  end
end
