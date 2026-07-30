# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::LevelThresholds do
  let(:ladder) do
    table = Huayu::LevelThresholds::SCALES.to_h do |scale|
      [scale, (1..7).to_h { |level| [level.to_s, {"third" => 10, "half" => 15, "twothirds" => 20}] }]
    end

    Huayu::LevelLadder.new(table: table)
  end

  subject(:thresholds) { described_class.new(ladder: ladder) }

  before do
    create(:lexeme, kind: :word, text: "我", data: {"tbcl_grade" => "1"})
    create(:lexeme, kind: :word, text: "喜歡", data: {"tbcl_grade" => "1"})
    create(:lexeme, kind: :word, text: "討論", data: {"tbcl_grade" => "4"})
    create(:lexeme, kind: :word, text: "議題", data: {"tbcl_grade" => "6"})
  end

  def tbcl(tokens) = thresholds.for_tokens("tbcl", tokens)

  it "sets the threshold to the level of the hardest token" do
    expect(tbcl(%w[我 喜歡 討論])[:tbcl_at0]).to(eq(4))
  end

  it "does not move the threshold at step zero" do
    expect(tbcl(%w[我 喜歡 討論 議題])[:tbcl_at0]).to(eq(6))
  end

  it "lowers the threshold exactly at the steps the share fits into" do
    row = tbcl(%w[我 喜歡 我 喜歡 我 討論 議題])

    expect(row[:tbcl_at0]).to(eq(6))
    expect(row[:tbcl_third]).to(eq(6))
    expect(row[:tbcl_half]).to(eq(4))
    expect(row[:tbcl_twothirds]).to(eq(4))
  end

  it "treats an ungraded token as above every level" do
    row = tbcl(%w[我 喜歡 沒有這個詞])

    expect(row[:tbcl_at0]).to(eq(described_class::NEVER))
    expect(row[:tbcl_twothirds]).to(eq(described_class::NEVER))
  end

  it(
    "admits an unknown token when its share fits the step"
  ) do
    row = tbcl(%w[我 喜歡 我 喜歡 我 喜歡 沒有這個詞])

    expect(row[:tbcl_at0]).to(eq(described_class::NEVER))
    expect(row[:tbcl_half]).to(eq(1))
  end

  it "returns NEVER for an empty parse" do
    expect(tbcl([])[:tbcl_at0]).to(eq(described_class::NEVER))
  end

  it "gives a word its own level at every step" do
    expect(thresholds.for_level("tocfl", 3).values.uniq).to(eq([3]))
  end

  it "keeps the threshold monotonic across levels" do
    row = tbcl(%w[我 喜歡 討論 議題])

    Huayu::LevelLadder::STEPS.each do |step|
      value = row[:"tbcl_#{step}"]
      next if value == described_class::NEVER

      expect(value).to(be_between(1, described_class::MAX_LEVEL))
    end
  end

  it "names its columns without reading the database, so class bodies can boot without one" do
    allow(described_class).to(receive(:instance).and_raise("the instance must not be built to name columns"))

    described_class::SCALES.each do |scale|
      expect(described_class.columns_for(scale)).to(be_present)
    end
  end
end
