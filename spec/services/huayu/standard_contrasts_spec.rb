# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::StandardContrasts do
  before { described_class.reset! }

  after { described_class.reset! }

  def locales = described_class.data.except("words")

  it "returns the contrast of the reader's language and nothing for an unknown one" do
    english = described_class.for("initials", "zh", "en")

    expect(english).to(include("taipei", "beijing"))
    expect(described_class.for("initials", "zh", "ru")).to(include("taipei", "beijing"))
    expect(described_class.for("initials", "zh", "ru")).not_to(eq(english))
    expect(described_class.for("initials", "zh", "id")).to(eq(described_class.data.dig("ind", "initials", "zh")))
    expect(described_class.for("initials", "zh", "xx")).to(be_nil)
  end

  it "gives every language the same sections, keys and sides as English" do
    shape = -> (sections) { sections.transform_values { |entries| entries.transform_values(&:keys) } }
    english = shape.call(described_class.contrasts("en"))

    Locales::ALL.each do |locale|
      expect(shape.call(described_class.contrasts(locale))).to(eq(english), locale)
    end
  end

  it "returns nothing for an item without a contrast" do
    expect(described_class.for("initials", "m", "en")).to(be_nil)
    expect(described_class.for("nowhere", "zh", "en")).to(be_nil)
  end

  it "drops a blank side and returns nothing when both are blank" do
    allow(described_class).to(
      receive(:data).and_return(
        "en" => {
          "tones" => {
            "t1" => {"taipei" => "High.", "beijing" => ""},
            "t2" => {"taipei" => " ", "beijing" => nil}
          }
        }
      )
    )

    expect(described_class.for("tones", "t1", "en")).to(eq("taipei" => "High."))
    expect(described_class.for("tones", "t2", "en")).to(be_nil)
  end

  it "keeps every section it knows and no other" do
    locales.each_value do |sections|
      expect(sections.keys - described_class::SECTIONS).to(be_empty)
    end
  end

  it "attaches every phonetics contrast to a row that exists" do
    rows = {
      "initials" => Huayu::Phonetics.initials,
      "finals" => Huayu::Phonetics.finals,
      "rimes" => Huayu::Phonetics.rimes
    }

    locales.each_value do |sections|
      rows.each do |section, list|
        known = list.map { |row| row["pinyin"] }

        expect(sections.fetch(section, {}).keys - known).to(be_empty, section)
      end
    end
  end

  it "attaches every block contrast to a block the chart shows" do
    known = Huayu::ZhuyinTrainer::BLOCKS.map { |block| block[:key] } + %w[compound series_hard]

    locales.each_value do |sections|
      expect(sections.fetch("blocks", {}).keys - known).to(be_empty)
    end
  end

  it "attaches every tone contrast to a place the tones page renders" do
    locales.each_value do |sections|
      expect(sections.fetch("tones", {}).keys - described_class::TONE_SLOTS).to(be_empty)
    end
  end

  it "gives every entry only the two sides and at least one of them" do
    locales.each_value do |sections|
      sections.each_value do |entries|
        entries.each do |key, entry|
          expect(entry.keys - described_class::SIDES).to(be_empty, key)
          expect(entry.values_at(*described_class::SIDES)).to(be_any(&:present?), key)
        end
      end
    end
  end

  it "lists words whose two readings really differ" do
    expect(described_class.words).not_to(be_empty)

    described_class.words.each do |word|
      expect(word["text"]).to(be_present)
      expect(word.dig("taipei", "zhuyin")).to(be_present, word["text"])
      expect(word.dig("taipei", "pinyin")).to(be_present, word["text"])
      expect(word["beijing"]).to(be_present, word["text"])
      expect(word.dig("taipei", "pinyin")).not_to(eq(word["beijing"]), word["text"])
    end
  end
end
