FactoryBot.define do
  factory :word_bookmark do
    association :user
    association :word
  end
end
