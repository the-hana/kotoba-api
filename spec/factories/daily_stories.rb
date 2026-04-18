FactoryBot.define do
  factory :daily_story do
    sequence(:story_date) { |n| Date.today - n }
    content { "今日は良い天気です。" }
    content_korean { "오늘은 좋은 날씨입니다." }
  end
end
