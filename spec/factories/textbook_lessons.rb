# frozen_string_literal: true

FactoryBot.define do
  factory(:textbook_lesson) do
    book { 1 }
    sequence(:lesson) { |n| n }
    title_en { "Lesson #{lesson}" }
    vocabulary { [] }
  end
end
