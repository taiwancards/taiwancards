# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::WordProfile do
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  let!(:word) { Lexeme.create!(kind: :word, text: "咖啡", meanings: {"en" => "coffee"}) }

  def example(text, difficulty:, gdex:, meanings: {"en" => "translated"}, audio: false)
    data = audio ? {"audio" => "common_voice"} : {}
    sentence = Lexeme.new(kind: :sentence, text:, meanings:, data:)
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    SentenceProfile.create!(
      lexeme: sentence,
      difficulty:,
      han_length: text.scan(/\p{Han}/).length,
      registers: [ContentSource.registers[source.register]],
      source_ids: [source.id]
    )
    SentenceWord.create!(sentence:, lexeme: word, gdex:)
    sentence
  end

  it "puts sentences that have a clip ahead of equally good silent ones" do
    example("我每天早上喝咖啡。", difficulty: 100, gdex: 900)
    with_audio = example("他在店裡喝咖啡。", difficulty: 300, gdex: 500, audio: true)

    expect(described_class.new(word).sentences.first.text).to(eq(with_audio.text))
  end

  it "still prefers translated sentences over untranslated ones with a clip" do
    translated = example("我喜歡喝咖啡。", difficulty: 500, gdex: 100)
    example("咖啡很好喝。", difficulty: 10, gdex: 999, meanings: {}, audio: true)

    texts = described_class.new(word).sentences.map(&:text)
    expect(texts.first).to(eq(translated.text))
  end

  it "reaches a recorded example that ranks far below the best silent ones" do
    30.times { |n| example("我每天早上喝咖啡#{n}。", difficulty: 10, gdex: 999 - n) }
    buried = example("他在店裡喝咖啡。", difficulty: 900, gdex: 1, audio: true)

    expect(described_class.new(word).sentences.map(&:text)).to(include(buried.text))
  end
end
