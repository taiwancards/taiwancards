# frozen_string_literal: true

FactoryBot.define do
  factory(:content_source) do
    sequence(:slug) { |n| "source-#{n}" }
    name { "Spoken" }
    register { :colloquial }
    license_commercial { true }
    enabled { true }
    enabled_for_admins { true }
    attribution { "Spoken." }
  end
end
