# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ZhuyinTrainer do
  it "drills only the block it was handed" do
    trainer = described_class.new({}, block: "velar", seed: 1)

    expect(trainer.scope_symbols).to(eq(%w[ㄍ ㄎ ㄏ]))
    expect(trainer.items(count: 12).map { |item| item[:symbol] }.uniq).to(match_array(%w[ㄍ ㄎ ㄏ]))
  end

  it "no longer hands a beginner the same four symbols over and over when a block is chosen" do
    labial = described_class.new({}, block: "labial", seed: 1)
    nasal = described_class.new({}, block: "nasal", seed: 1)

    expect(labial.items(count: 8).map { |item| item[:symbol] }.uniq).to(match_array(%w[ㄅ ㄆ ㄇ ㄈ]))
    expect(nasal.items(count: 8).map { |item| item[:symbol] }.uniq).to(match_array(%w[ㄢ ㄣ ㄤ ㄥ]))
  end

  it "falls back to the whole group when only a group is given" do
    trainer = described_class.new({}, group: "finals", seed: 1)

    expect(trainer.scope_symbols).to(include("ㄧ", "ㄚ", "ㄞ", "ㄢ", "ㄦ"))
    expect(trainer.scope_symbols).not_to(include("ㄅ"))
  end

  it "ignores a block that does not exist" do
    trainer = described_class.new({}, block: "nonsense", seed: 1)

    expect(trainer.block).to(be_nil)
    expect(trainer.scope_symbols).to(eq(described_class::ALL))
  end

  it "counts progress against the chosen block alone" do
    mastery = %w[ㄍ ㄎ].to_h { |symbol| [symbol, {"streak" => 3}] }
    trainer = described_class.new(mastery, block: "velar")

    expect(trainer.progress).to(eq({mastered: 2, total: 3}))
    expect(trainer).not_to(be_complete)
  end

  it "knows which block a symbol belongs to, so the theory can link to it" do
    expect(described_class.block_for("ㄓ")[:key]).to(eq("retroflex"))
    expect(described_class.blocks_in("initials").map { |block| block[:key] }).to(include("labial", "sibilant"))
    expect(described_class.blocks_in("initials").map { |block| block[:key] }).not_to(include("nasal"))
  end
end
