FactoryBot.define do
  factory :study_session do
    association :user
    association :word_day
  end
end
