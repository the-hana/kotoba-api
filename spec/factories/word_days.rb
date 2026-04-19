FactoryBot.define do
  factory :word_day do
    association :word
    day_number { 1 }
  end
end
