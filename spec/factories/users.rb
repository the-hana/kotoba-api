FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    nickname { Faker::Name.first_name }
    password { "password123" }
    password_confirmation { "password123" }
    target_level { "n5" }
  end
end
