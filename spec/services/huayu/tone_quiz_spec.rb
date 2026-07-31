# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ToneQuiz do
  def word(text, pinyin)
    create(:lexeme, kind: :word, text:, readings: {"pinyin" => pinyin}, meanings: {"en" => "gloss"})
  end

  it "offers four options, exactly one of them right" do
    options = described_class.new(word("學校", "xué xiào")).call

    expect(options.size).to(eq(4))
    expect(options.count(&:correct)).to(eq(1))
  end

  it "spells the right option with the word's own tones" do
    options = described_class.new(word("學校", "xué xiào")).call

    expect(options.find(&:correct).tones).to(eq([2, 4]))
    expect(options.find(&:correct).pinyin).to(eq("xué xiào"))
  end

  it "keeps every option on the same syllables so only the tones differ" do
    options = described_class.new(word("中文", "zhōng wén")).call
    bare = options.map { |option| Huayu::ReadingForms.plain_pinyin(option.pinyin) }

    expect(options.map(&:tones).uniq.size).to(eq(4))
    expect(bare.uniq).to(eq(["zhongwen"]))
  end

  it "picks tones that are actually confusable with the right ones" do
    options = described_class.new(word("老師", "lǎo shī")).call
    wrong = options.reject(&:correct).map(&:tones)

    expect(wrong).to(all(satisfy { |tones| tones.zip([3, 1]).count { |a, b| a != b } <= 2 }))
  end

  it "varies the tone in different syllables rather than always the first" do
    options = described_class.new(word("中文", "zhōng wén")).call
    changed = options.reject(&:correct).map { |option| option.tones.zip([1, 2]).index { |a, b| a != b } }

    expect(changed.uniq.size).to(be >= 2)
  end

  it "marks a neutral tone with the raised dot rather than a suffix" do
    options = described_class.new(word("謝謝", "xiè xie")).call

    expect(options.find(&:correct).zhuyin).to(include("˙"))
  end

  it "writes the first tone with a macron" do
    options = described_class.new(word("中文", "zhōng wén")).call

    expect(options.find(&:correct).pinyin).to(eq("zhōng wén"))
  end

  it "stays the same between two renders of the same card" do
    lexeme = word("學校", "xué xiào")

    expect(described_class.new(lexeme).call.map(&:tones)).to(eq(described_class.new(lexeme).call.map(&:tones)))
  end

  it "declines a word it cannot read" do
    expect(described_class.new(word("莫名", "")).available?).to(be(false))
  end

  it "declines a word longer than it can quiz" do
    expect(described_class.new(word("不好意思啦", "bù hǎo yì si la")).available?).to(be(false))
  end
end
