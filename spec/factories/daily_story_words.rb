FactoryBot.define do
  factory :daily_story_word do
    association :daily_story
    association :word
  end
end
