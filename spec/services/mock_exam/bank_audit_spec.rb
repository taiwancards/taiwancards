# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockExam::BankAudit do
  let(:issues) { described_class.new.call }

  it "keeps every item inside the word list of its own level" do
    expect(issues.map(&:to_s)).to(eq([]))
  end

  it "translates every reading item up to B1 into Vietnamese" do
    untranslated = %w[Novice1 Novice2 A1 A2 B1].flat_map do |level|
      MockExam::Bank.blocks(level).flat_map do |block|
        missing = block.names["vi"].blank? ? [block.id] : []
        missing +
          block.questions.filter_map { |question|
            block.id if question.names["en"].present? && question.names["vi"].blank?
          }
      end
    end

    expect(untranslated).to(eq([]))
  end

  it "carries fifty questions for every level" do
    counts = MockExam::Bank::LEVELS.index_with { |level| MockExam::Bank.questions(level) }

    expect(counts.values).to(all(eq(50)))
  end

  it "offers the official item formats for the level" do
    expect(MockExam::Bank.formats("Novice1")).to(eq(%w[sentence sign cloze]))
    expect(MockExam::Bank.formats("A1")).to(eq(%w[sentence sign paragraph cloze]))
    expect(MockExam::Bank.formats("A2")).to(eq(%w[sentence sign paragraph cloze]))
    expect(MockExam::Bank.formats("B1")).to(eq(%w[cloze passage]))
  end

  it "spreads the answer key evenly enough to defeat guessing" do
    MockExam::Bank::LEVELS.each do |level|
      keys = MockExam::Bank.blocks(level).flat_map { |block| block.questions.map(&:answer) }
      share = keys.tally.values.map { |count| count.to_f / keys.size }
      even = 1.0 / MockExam::Bank.choices(level)

      expect(share.max - even).to(be < 0.1, "#{level} leans on one option: #{keys.tally.sort.inspect}")
    end
  end

  it "never repeats an option inside a question" do
    duplicated = MockExam::Bank.all.flat_map do |block|
      block.questions.filter_map { |question| block.id if question.options.uniq.size != question.options.size }
    end

    expect(duplicated).to(eq([]))
  end
end
