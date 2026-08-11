# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockExam::Paper do
  it "draws the same paper for the same seed" do
    first = described_class.build(level: "A1", seed: 42)
    second = described_class.build(level: "A1", seed: 42)

    expect(first.slots.map { |slot| slot.question.key }).to(eq(second.slots.map { |slot| slot.question.key }))
  end

  it "draws a different paper for a different seed" do
    first = described_class.build(level: "A1", seed: 1)
    second = described_class.build(level: "A1", seed: 2)

    expect(first.groups.map { |group| group.block.id }).not_to(eq(second.groups.map { |group| group.block.id }))
  end

  it "fills exactly ten questions on every level and seed" do
    MockExam::Bank::LEVELS.each do |level|
      counts = (1..60).map { |seed| described_class.build(level: level, seed: seed).count }

      expect(counts.uniq).to(eq([described_class::COUNT]), "#{level} drew #{counts.uniq.inspect}")
    end
  end

  it "keeps a block whole and numbers the questions in one run" do
    sheet = described_class.build(level: "B1", seed: 11)

    sheet.groups.each do |group|
      expect(group.slots.size).to(eq(group.block.size))
    end

    expect(sheet.slots.map(&:number)).to(eq((1..sheet.count).to_a))
  end

  it "orders the paper by the official section order" do
    sheet = described_class.build(level: "A2", seed: 5)
    positions = sheet.groups.map { |group| MockExam::Bank::FORMATS.index(group.format) }

    expect(positions).to(eq(positions.sort))
  end

  it "mixes more than one format into a paper" do
    mixed = (1..30).map { |seed| described_class.build(level: "A1", seed: seed).formats.size }

    expect(mixed.min).to(be >= 2)
  end
end
