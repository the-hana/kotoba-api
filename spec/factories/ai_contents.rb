FactoryBot.define do
  factory :ai_content do
    association :word
    association :daily_story
    example_sentence { "これは例文です。" }
    example_sentence_korean { "이것은 예문입니다." }
  end
end
