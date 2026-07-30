# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ExampleQuality do
  let(:frequency) { instance_double(Huayu::WordFrequency) }
  let(:scorer) { described_class.new(frequency:) }

  before { allow(frequency).to(receive(:adjusted).and_return(50.0)) }

  def score(text, segments, target, **rest)
    scorer.call(text:, segments:, target:, **rest)
  end

  it "rejects a sentence shorter than the floor" do
    expect(score("咖啡", %w[咖啡], "咖啡")).to(eq(0))
  end

  it "rejects a sentence longer than the ceiling" do
    text = "#{"我今天要去便利商店買一杯咖啡" * 4}。"

    expect(score(text, %w[咖啡], "咖啡")).to(eq(0))
  end

  it "rejects a sentence that does not contain the target" do
    expect(score("我今天要去買東西。", %w[我 今天 要 去 買 東西], "咖啡")).to(eq(0))
  end

  it "prefers a complete sentence over a fragment" do
    segments = %w[我 今天 買 咖啡]
    complete = score("我今天買咖啡。", segments, "咖啡")
    fragment = score("我今天買咖啡", segments, "咖啡")

    expect(complete).to(be > fragment)
  end

  it "penalises an opening anaphor" do
    plain = score("我今天買了咖啡。", %w[我 今天 買 了 咖啡], "咖啡")
    anaphoric = score("這樣今天買了咖啡。", %w[這樣 今天 買 了 咖啡], "咖啡")

    expect(plain).to(be > anaphoric)
  end

  it "penalises a repeated target at equal length" do
    once = score("我今天下午喝了咖啡。", %w[我 今天 下午 喝 了 咖啡], "咖啡")
    twice = score("我今天喝咖啡也買咖啡。", %w[我 今天 喝 咖啡 也 買 咖啡], "咖啡")

    expect(once).to(be > twice)
  end

  it "penalises rare vocabulary around the target" do
    text = "罕見詞彙充斥的咖啡句子。"
    segments = %w[罕見 詞彙 充斥 的 咖啡 句子]
    common = score(text, segments, "咖啡")

    allow(frequency).to(receive(:adjusted).and_return(0.1))
    allow(frequency).to(receive(:adjusted).with("咖啡").and_return(50.0))
    rare = described_class.new(frequency:).call(text:, segments:, target: "咖啡")

    expect(common).to(be > rare)
  end

  it "prefers an easier sentence at equal shape" do
    segments = %w[我 今天 買 咖啡]
    easy = score("我今天買咖啡。", segments, "咖啡", difficulty: 100)
    hard = score("我今天買咖啡。", segments, "咖啡", difficulty: 900)

    expect(easy).to(be > hard)
  end

  it "stays inside the scale" do
    segments = %w[我 今天 買 咖啡]
    value = score("我今天買咖啡。", segments, "咖啡", difficulty: 0, taiwan: 9)

    expect(value).to(be_between(0, described_class::SCALE))
  end
end
