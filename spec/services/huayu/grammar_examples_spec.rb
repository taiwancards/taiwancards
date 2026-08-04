# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Grammar example sentences" do
  let(:lessons) { Huayu::GrammarLessons.taught }
  let(:examples) { lessons.flat_map { |lesson| lesson.examples.map { |example| [lesson, example] } } }

  it "has a syllabus to check" do
    expect(lessons.size).to(be > 400)
    expect(examples.size).to(be > 1500)
  end

  it "translates every example into both languages" do
    missing = examples.reject { |_, example| example.ru.present? && example.en.present? }

    expect(missing.map { |lesson, example| "#{lesson.slug}: #{example.zh}" }).to(be_empty)
  end

  it "reads every example out in zhuyin, one syllable per character, and in pinyin" do
    mismatched = examples.reject do |_, example|
      example.syllables.size == example.zh.scan(/\p{Han}/).size && example.pinyin.present?
    end

    expect(mismatched.map { |lesson, example| "#{lesson.slug}: #{example.zh}" }).to(be_empty)
  end

  it "reads 和 as hàn wherever it joins or accompanies, never as hé" do
    conjunctions = examples
      .map { |lesson, example| [lesson, example] }
      .select { |_, example| example.zh.include?("和") && !example.zh.include?("和平") }

    expect(conjunctions).not_to(be_empty)
    conjunctions.each do |lesson, example|
      index = example.zh.scan(/\p{Han}/).index("和")
      expect(example.syllables[index]).to(eq("ㄏㄢˋ"), "#{lesson.slug}: #{example.zh}")
      expect(example.pinyin).to(include("hàn"), "#{lesson.slug}: #{example.zh}")
    end
  end

  it "does not print one example twice inside the same point" do
    repeated = lessons.flat_map do |lesson|
      shapes = lesson.examples.map { |example| example.zh.gsub(/\P{Han}/, "") }
      shapes.combination(2).filter_map do |left, right|
        short, long = [left, right].sort_by(&:length)
        "#{lesson.slug}: #{short} ⊂ #{long}" if short.length >= 4 && long.include?(short)
      end
    end

    expect(repeated).to(be_empty)
  end

  it "writes every stored link as a sentence public id" do
    ids = examples.filter_map { |_, example| example.sentence.presence }.uniq

    expect(ids).not_to(be_empty)
    expect(ids.reject { |id| id.match?(Lexeme::PUBLIC_ID_FORMAT) }).to(be_empty)
  end
end
