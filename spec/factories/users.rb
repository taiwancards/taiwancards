# frozen_string_literal: true

FactoryBot.define do
  factory(:user) do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    password { "password12" }
    email_verified_at { Time.current }
    prefs { {"goal" => "guided"} }

    trait(:undecided) do
      prefs { {"language_chosen" => true} }
    end

    trait(:new_arrival) do
      prefs { {} }
    end

    trait(:admin) do
      email { User.owner_email || User.owner_google_email }
      restricted_content { true }
      google_email { User.owner_google_email }
      google_uid { "google-admin" }
    end
  end
end
