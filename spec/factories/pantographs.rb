# encoding: utf-8

FactoryGirl.define do
  factory :pantograph do
    body { Faker::Lorem.characters(140) }
    pantographer_id 0
    sequence(:external_created_at) { |n| (1000 - n).days.ago }
    sequence(:tweet_id) { |n| "#{n}" }
  end
end