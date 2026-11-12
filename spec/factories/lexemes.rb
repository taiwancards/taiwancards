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

    trait(:sentence) do
      transient do
        content_source { association(:content_source) }
        segments { text.scan(/\p{Han}/) }
        difficulty { 100 }
        level { 1 }
      end

      kind { :sentence }
      sequence(:text) { |n| "這是第#{n.to_s.tr("0-9", "〇一二三四五六七八九")}句話。" }
      meanings { {} }
      data do
        {
          "difficulty" => difficulty,
          "length" => text.scan(/\p{Han}/).length,
          "taiwan" => 0,
          "segments" => segments
        }
      end

      after(:build) do |sentence, context|
        sentence.lexeme_content_sources.build(content_source: context.content_source)
      end

      after(:create) do |sentence, context|
        SentenceProfile.create!(
          lexeme: sentence,
          difficulty: context.difficulty,
          han_length: sentence.data["length"],
          tocfl_index: context.level,
          tbcl_index: context.level,
          source_ids: [context.content_source.id],
          registers: [ContentSource.registers[context.content_source.register]].compact
        )
      end
    end
  end
end
