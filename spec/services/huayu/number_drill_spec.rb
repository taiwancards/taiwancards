# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::NumberDrill do
  subject(:drill) { described_class.new(seed: 20_260_719) }

  it "builds every stage with four distinct options" do
    described_class::STAGES.each do |stage|
      items = drill.items(stage, count: 6)

      expect(items.size).to(eq(6), stage)
      items.each do |item|
        options = [item[:answer], *item[:distractors]]
        expect(options.size).to(eq(described_class::CHOICES), "#{stage} #{item[:id]}")
        expect(options.uniq.size).to(eq(described_class::CHOICES), "#{stage} #{item[:id]} #{options.inspect}")
        expect(item[:answer]).to(be_present)
      end
    end
  end

  it "groups the arabic side by four digits, matching the myriad system" do
    item = drill.items("myriads", count: 6).find { |i| i[:id] == "myriad:1000000" }

    expect(item[:prompt]).to(eq("100 0000"))
    expect(item[:answer]).to(eq("一百萬"))
  end

  it "offers a magnitude slip as the distractor, not a random number" do
    item = drill.items("myriads", count: 6).find { |i| i[:id] == "myriad:100000" }

    expect(item[:answer]).to(eq("十萬"))
    expect(item[:distractors]).to(include("一百萬"))
  end

  it "traps the 二 and 兩 confusion with the real alternative form" do
    item = drill.items("traps", count: 12).find { |i| i[:id] == "trap:200" }

    expect(item[:answer]).to(eq("兩百"))
    expect(item[:distractors]).to(include("二百"))
  end

  it "traps a dropped 零" do
    item = drill.items("traps", count: 12).find { |i| i[:id] == "trap:105" }

    expect(item[:answer]).to(eq("一百零五"))
    expect(item[:distractors]).to(include("一百五"))
  end

  it "converts ROC years the way Taiwanese paperwork does" do
    item = drill.items("taiwan", count: 4).first

    roc = item[:id].split(":").last.to_i
    expect(item[:answer].to_i).to(eq(roc + 1911))
    expect(item[:prompt]).to(start_with("民國"))
  end

  it "is reproducible for a given seed" do
    a = described_class.new(seed: 42).items("reading", count: 5)
    b = described_class.new(seed: 42).items("reading", count: 5)

    expect(a).to(eq(b))
  end
end
