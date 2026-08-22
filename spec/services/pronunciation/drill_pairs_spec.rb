# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::DrillsBuilder do
  def quality(*keys)
    keys.map { |key| {"key" => key, "n" => 8, "self" => 95, "top1" => 30.0, "margin" => -4} }
  end

  def pair(family, keys, accuracy, nucleus: nil)
    {"family" => family, "keys" => keys, "accuracy" => accuracy, "n" => 12, "nucleus" => nucleus}.compact
  end

  def sections(quality_rows, contrast_rows)
    described_class.new(quality: quality_rows, contrasts: contrast_rows, io: nil).call["sections"]
  end

  def section(rows, id) = rows.find { |candidate| candidate["id"] == id }

  it "keeps a pair we tell apart even when neither syllable is easy to pick out of the whole inventory" do
    rows = sections(quality("ba1", "pa1"), [pair("aspiration", %w[ba1 pa1], 92.0)])

    expect(section(rows, "aspiration")["pairs"]).to(eq([%w[ba1 pa1]]))
  end

  it "drops a pair we cannot tell apart" do
    rows = sections(quality("ba1", "pa1"), [pair("aspiration", %w[ba1 pa1], 55.0)])

    expect(section(rows, "aspiration")["pairs"]).to(be_empty)
  end

  it "drops a pair whose member does not even match its own template" do
    weak = quality("ba1") + [{"key" => "pa1", "n" => 8, "self" => 40, "top1" => 90.0, "margin" => 20}]
    rows = sections(weak, [pair("aspiration", %w[ba1 pa1], 92.0)])

    expect(section(rows, "aspiration")["pairs"]).to(be_empty)
  end

  it "offers no nasal coda drill, because that contrast is a coin toss on an unfamiliar voice" do
    rows = sections(quality("ban1", "bang1"), [pair("coda", %w[ban1 bang1], 95.0, nucleus: "a")])

    expect(section(rows, "coda_a")).to(be_nil)
  end

  it "ranks the pairs we tell apart best first" do
    rows = sections(
      quality("ba1", "pa1", "da1", "ta1"),
      [pair("aspiration", %w[ba1 pa1], 78.0), pair("aspiration", %w[da1 ta1], 95.0)]
    )

    expect(section(rows, "aspiration")["pairs"].first).to(eq(%w[da1 ta1]))
  end
end
