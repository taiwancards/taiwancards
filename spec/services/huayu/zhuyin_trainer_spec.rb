# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ZhuyinTrainer do
  def trainer(mastery = {}) = described_class.new(mastery, seed: 7)

  it "covers all 37 bopomofo symbols exactly once" do
    expect(described_class::ALL.size).to(eq(37))
    expect(described_class::ALL.uniq.size).to(eq(37))
  end

  it "starts on the first block and unlocks nothing beyond it" do
    subject = trainer

    expect(subject.current_block[:key]).to(eq("labial"))
    expect(subject.unlocked_symbols).to(eq(%w[ㄅ ㄆ ㄇ ㄈ]))
  end

  it "opens the next block only once the previous one is mastered" do
    mastery = %w[ㄅ ㄆ ㄇ ㄈ].index_with { {"streak" => 3} }
    subject = trainer(mastery)

    expect(subject.current_block[:key]).to(eq("alveolar"))
    expect(subject.unlocked_symbols).to(include("ㄅ", "ㄉ"))
  end

  it "offers close distractors rather than random symbols" do
    item = trainer.item_for("ㄅ")

    expect(item[:options]).to(include("ㄅ"))
    expect(item[:options].size).to(eq(described_class::CHOICES))
    expect(item[:options] - %w[ㄅ ㄆ ㄉ ㄊ]).to(be_empty)
  end

  it "keeps the retroflex and palatal series apart as distractors" do
    expect(trainer.item_for("ㄓ")[:options]).to(include("ㄔ"))
    expect(trainer.item_for("ㄐ")[:options]).to(include("ㄑ"))
  end

  it "counts a symbol as mastered after three quick correct answers" do
    subject = trainer
    3.times { subject.record("ㄅ", correct: true, elapsed_ms: 900) }

    expect(subject).to(be_mastered("ㄅ"))
  end

  it "does not advance the streak when the answer was slow" do
    subject = trainer
    3.times { subject.record("ㄅ", correct: true, elapsed_ms: 9000) }

    expect(subject).not_to(be_mastered("ㄅ"))
  end

  it "resets the streak on a wrong answer" do
    subject = trainer
    2.times { subject.record("ㄅ", correct: true, elapsed_ms: 900) }
    subject.record("ㄅ", correct: false, elapsed_ms: 900)
    subject.record("ㄅ", correct: true, elapsed_ms: 900)

    expect(subject).not_to(be_mastered("ㄅ"))
  end

  it "drills the unmastered symbols of the open block" do
    mastery = {"ㄅ" => {"streak" => 3}}
    items = trainer(mastery).items(count: 12)

    expect(items.map { |item| item[:symbol] }.uniq).to(match_array(%w[ㄆ ㄇ ㄈ]))
  end

  it "reports completion only when every symbol is mastered" do
    expect(trainer).not_to(be_complete)

    all = described_class::ALL.index_with { {"streak" => 3} }
    expect(trainer(all)).to(be_complete)
  end

  it "points each item at a real audio clip" do
    described_class::ALL.each do |symbol|
      path = Rails.root.join("public", "zhuyin", "#{symbol}.opus")
      expect(path).to(exist, symbol)
    end
  end
end
