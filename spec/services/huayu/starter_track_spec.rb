# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::StarterTrack do
  before { described_class.reset! }

  after { described_class.reset! }

  let(:marks) { %w[ˊ ˇ ˋ ˙] }
  let(:alphabet) {
    (Huayu::Zhuyin::INITIALS.values + Huayu::Zhuyin::FINALS.values.select { |symbol| symbol.length == 1 }).uniq
  }

  it "introduces every zhuyin symbol exactly once" do
    introduced = described_class.lessons.flat_map(&:symbols)

    expect(introduced).to(match_array(alphabet))
  end

  it "keeps every lesson short and every word glossed in both interface languages" do
    described_class.lessons.each do |lesson|
      expect(lesson.symbols.size).to(be <= 5, "#{lesson.slug} introduces too many symbols")
      expect(lesson.words.size).to(be_between(3, 7), "#{lesson.slug} has #{lesson.words.size} words")
      lesson.words.each { |word| expect(word.glosses.keys).to(include("en", "ru"), "#{word.zh} lacks a gloss") }
      expect(lesson.title_for(:en)).to(be_present)
      expect(lesson.title_for(:ru)).to(be_present)
    end
  end

  it "spells every phrase with one zhuyin syllable per character" do
    described_class.lessons.filter_map(&:phrase).each do |phrase|
      expect(phrase.zhuyin.split.size).to(eq(phrase.zh.scan(/\p{Han}/).size), phrase.zh)
      expect(phrase.zhuyin.delete("#{marks.join} ").chars).to(all(satisfy { |symbol| alphabet.include?(symbol) }))
    end
  end
end
