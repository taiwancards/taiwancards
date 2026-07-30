# frozen_string_literal: true

FactoryBot.define do
  factory(:lexeme) do
    kind { :word }
    sequence(:text) { |n| "詞#{n}" }
    readings { {} }
    meanings { {"en" => "meaning"} }

    trait(:character) do
      kind { :character }
      sequence(:text) { |n| [0x4E00 + n].pack("U") }
    end

    trait(:phrase) do
      kind { :phrase }
      sequence(:text) { |n| "句子#{n}" }
    end
  end
end
