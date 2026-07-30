# frozen_string_literal: true

FactoryBot.define do
  factory(:user) do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    password { "password12" }
    password_confirmation { "password12" }
    email_verified_at { Time.current }

    trait(:unverified) do
      email_verified_at { nil }
    end

    trait(:zh_only) do
    end
  end
end
