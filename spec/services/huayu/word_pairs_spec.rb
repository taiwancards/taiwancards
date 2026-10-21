# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::WordPairs do
  let(:pairs) { described_class.lessons }

  it "keys every drill to one of its own options and leaves exactly one blank" do
    pairs.flat_map(&:exercises).each do |exercise|
      expect(exercise.zh.scan(described_class::BLANK).size).to(eq(1), exercise.zh)
      expect(exercise.options).to(include(exercise.right_option), exercise.zh)
      expect(exercise.options.uniq.size).to(eq(exercise.options.size), exercise.zh)
    end
  end

  it "explains every answer in both languages" do
    pairs.each do |pair|
      pair.exercises.each do |exercise|
        %i[en ru].each do |locale|
          note = pair.explain(exercise, locale)
          expect(note.body).to(be_present, "#{pair.slug} #{exercise.zh}")
          expect(note.zh).not_to(include(described_class::BLANK))
        end
      end
    end
  end

  it "teaches only words that belong to the set and reads each of them" do
    pairs.each do |pair|
      expect(pair.uses.map(&:word) - pair.texts).to(be_empty, pair.slug)
      expect(pair.words.map(&:zhuyin)).to(all(be_present), pair.slug)
      pair.exercises.each do |exercise|
        expect(exercise.options).to(
          all(satisfy { |option| pair.texts.any? { |text| option.include?(text) } }),
          exercise.zh
        )
      end
    end
  end

  it "groups the sets by level and finds them from any of their words" do
    expect(described_class.levels.keys - described_class::LEVELS).to(be_empty)
    expect(described_class.for_word("能").map(&:slug)).to(include("hui-neng-keyi"))
    expect(described_class.for_word("貓")).to(be_empty)
  end

  it "writes every Chinese line in traditional characters" do
    lines = pairs.flat_map do |pair|
      pair.uses.flat_map(&:examples).map(&:zh) +
        pair.mistakes.map(&:right) +
        pair.exercises.map { |exercise| exercise.zh.sub(described_class::BLANK, exercise.right_option) }
    end

    lines.each { |line| expect(Huayu::SimpToTrad.convert(line).first).to(eq(line)) }
  end
end
