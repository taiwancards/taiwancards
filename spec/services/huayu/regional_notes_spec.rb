# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::RegionalNotes do
  before { described_class.reset! }

  after { described_class.reset! }

  it "returns the note of the reader's language and nothing for the others" do
    expect(described_class.for("initials", "sh", "vi")).to(be_present)
    expect(described_class.for("initials", "sh", "en")).to(be_nil)
    expect(described_class.for("initials", "sh", "ru")).to(be_nil)
  end

  it "returns nothing for an item without a note" do
    expect(described_class.for("initials", "m", "vi")).to(be_nil)
    expect(described_class.for("nowhere", "sh", "vi")).to(be_nil)
  end

  it "keeps every section it knows and no other" do
    described_class.data.each_value do |sections|
      expect(sections.keys - described_class::SECTIONS).to(be_empty)
    end
  end

  it "attaches every phonetics note to a row that exists" do
    rows = {
      "initials" => Huayu::Phonetics.initials,
      "finals" => Huayu::Phonetics.finals,
      "rimes" => Huayu::Phonetics.rimes
    }

    described_class.data.each_value do |sections|
      rows.each do |section, list|
        known = list.map { |row| row["pinyin"] }

        expect(sections.fetch(section, {}).keys - known).to(be_empty, section)
      end
    end
  end

  it "attaches every block note to a block the chart shows" do
    known = Huayu::ZhuyinTrainer::BLOCKS.map { |block| block[:key] } + %w[compound series_hard]

    described_class.data.each_value do |sections|
      expect(sections.fetch("blocks", {}).keys - known).to(be_empty)
    end
  end

  it "attaches every tone note to a place the tones page renders" do
    described_class.data.each_value do |sections|
      expect(sections.fetch("tones", {}).keys - described_class::TONE_SLOTS).to(be_empty)
    end
  end

  it "attaches every grammar note to a lesson that exists" do
    slugs = Huayu::GrammarLessons.all.map(&:slug)

    described_class.data.each_value do |sections|
      expect(sections.fetch("grammar", {}).keys - slugs).to(be_empty)
    end
  end

  it "attaches every particle note to a particle the section lists" do
    known = JSON.parse(AppData.path("huayu/particles.json").read).map { |row| row["text"] }

    described_class.data.each_value do |sections|
      expect(sections.fetch("particles", {}).keys - known).to(be_empty)
    end
  end

  it "opens each Vietnamese note with the region it speaks about" do
    described_class.data.fetch("vi").each_value do |notes|
      notes.each do |key, text|
        expect(text).to(match(/\AMiền (Nam|Trung)\b/), key)
      end
    end
  end

  it "never brings China into a Vietnamese note" do
    described_class.data.fetch("vi").each_value do |notes|
      notes.each do |key, text|
        expect(text).not_to(match(/Trung Quốc|Bắc Kinh|đại lục|phổ thông thoại|HSK/i), key)
      end
    end
  end
end
