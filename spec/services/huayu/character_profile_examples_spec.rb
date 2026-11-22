# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CharacterProfile do
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

  let!(:character) { Lexeme.create!(kind: :character, text: "離", meanings: {"en" => "to part"}) }

  def example(text, gdex:, meanings: {})
    sentence = Lexeme.new(kind: :sentence, text:, meanings:)
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    SentenceWord.create!(sentence:, lexeme: character, gdex:)
    sentence
  end

  it "puts translated examples before untranslated ones despite a lower gdex" do
    untranslated = example("離開一", gdex: 99)
    translated = example("離開二", gdex: 1, meanings: {"ru" => "уходить два"})

    I18n.with_locale(:ru) do
      expect(described_class.new(character, user: nil).phrases.map(&:id)).to(eq([translated.id, untranslated.id]))
    end
  end

  it "borrows the examples of the word written with the same single character when it has none of its own" do
    word = Lexeme.create!(kind: :word, text: "離", meanings: {"en" => "away from"})
    sentence = example("離這裡很遠", gdex: 5)
    SentenceWord.where(sentence:).update_all(lexeme_id: word.id)

    expect(described_class.new(character, user: nil).phrases.map(&:id)).to(eq([sentence.id]))
  end

  it "shows a single-character word the examples filed under its character" do
    word = Lexeme.create!(kind: :word, text: "離", meanings: {"en" => "away from"})
    sentence = example("離這裡很遠", gdex: 5)

    expect(Huayu::WordProfile.new(word, user: nil).sentences.map(&:id)).to(eq([sentence.id]))
  end

  it "never lends a longer word the examples of another entry" do
    word = Lexeme.create!(kind: :word, text: "離開", meanings: {"en" => "to leave"})
    Lexeme.create!(kind: :collocation, text: "離開", meanings: {"en" => "to leave"})
    example("離開這裡", gdex: 5)

    expect(Huayu::WordProfile.new(word, user: nil).sentences).to(be_empty)
  end

  it "falls back to quality order when nothing is translated" do
    low = example("離開三", gdex: 2)
    high = example("離開四", gdex: 40)

    I18n.with_locale(:ru) do
      expect(described_class.new(character, user: nil).phrases.map(&:id)).to(eq([high.id, low.id]))
    end
  end

  it "judges translation by the reader's own locale" do
    russian = example("離開五", gdex: 1, meanings: {"ru" => "уходить пять"})
    english = example("離開六", gdex: 2, meanings: {"en" => "leave six"})

    I18n.with_locale(:ru) do
      expect(described_class.new(character, user: nil).phrases.map(&:id)).to(eq([russian.id, english.id]))
    end

    I18n.with_locale(:en) do
      expect(described_class.new(character, user: nil).phrases.map(&:id)).to(eq([english.id, russian.id]))
    end
  end

  it "borrows the standard form's examples for a variant character that has none" do
    standard = Lexeme.create!(kind: :character, text: "裡", meanings: {"en" => "inside"})
    variant = Lexeme.create!(kind: :character, text: "裏", meanings: {"en" => "inside"})
    sentence = Lexeme.new(kind: :sentence, text: "屋子裡很暖和")
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    SentenceWord.create!(sentence:, lexeme: standard, gdex: 10)

    expect(described_class.new(variant, user: nil).phrases.map(&:id)).to(eq([sentence.id]))
    expect(described_class.new(character, user: nil).phrases).to(be_empty)
  end
end
