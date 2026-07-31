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

  let!(:word) { Lexeme.create!(kind: :word, text: "朋友", meanings: {"en" => "friend", "ru" => "друг"}) }

  def example(text, difficulty:, gdex:, meanings: {})
    sentence = Lexeme.new(kind: :sentence, text:, meanings:)
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

  let!(:both_easy) do
    example("朋友一", difficulty: 100, gdex: 1, meanings: {"en" => "friend one", "ru" => "друг один"})
  end

  let!(:both_hard) do
    example("朋友二", difficulty: 900, gdex: 2, meanings: {"en" => "friend two", "ru" => "друг два"})
  end

  let!(:english_only) do
    example("朋友三", difficulty: 500, gdex: 8, meanings: {"en" => "friend three"})
  end

  let!(:untranslated_easy) { example("朋友四", difficulty: 200, gdex: 9) }
  let!(:untranslated_hard) { example("朋友五", difficulty: 800, gdex: 10) }

  def texts(locale)
    I18n.with_locale(locale) { described_class.new(word).sentences.map(&:text) }
  end

  it "leads with the examples translated into the interface language" do
    expect(texts(:ru).first(2)).to(eq([both_easy.text, both_hard.text]))
  end

  it "orders each group from simple to complex" do
    expect(texts(:ru)).to(
      eq(
        [
          both_easy.text,
          both_hard.text,
          untranslated_easy.text,
          english_only.text,
          untranslated_hard.text
        ]
      )
    )
  end

  it "regroups when the interface language changes" do
    expect(texts(:en)).to(
      eq(
        [
          both_easy.text,
          english_only.text,
          both_hard.text,
          untranslated_easy.text,
          untranslated_hard.text
        ]
      )
    )
  end

  it "prefers a translated example over an untranslated one of higher example quality" do
    expect(texts(:ru).index(both_hard.text)).to(be < texts(:ru).index(untranslated_easy.text))
  end

  it "keeps every example that links to the word" do
    expect(texts(:ru).length).to(eq(5))
  end
end
