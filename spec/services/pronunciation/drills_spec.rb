# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Drills do
  let(:root) { Dir.mktmpdir }
  let(:payload) do
    {
      "sections" => [
        {
          "id" => "aspiration",
          "title" => {"ru" => "Придыхание", "en" => "Aspiration"},
          "kind" => "pair",
          "pairs" => [%w[gao1 kao1], %w[bi4 pi4], %w[di2 ti2], %w[ju4 qu4], %w[zhu2 chu2], %w[zang1 cang1]],
          "n_items" => 6,
          "thin" => false
        },
        {
          "id" => "coda_e",
          "title" => {"ru" => "-en против -eng", "en" => "-en vs -eng"},
          "kind" => "pair",
          "pairs" => [%w[chen2 cheng2]],
          "n_items" => 1,
          "thin" => true
        },
        {
          "id" => "vowel_a",
          "title" => {"ru" => "Гласный a", "en" => "Vowel a"},
          "kind" => "list",
          "keys" => %w[mao2 hao3 tiao2],
          "n_items" => 3,
          "thin" => true
        }
      ]
    }
  end

  before do
    File.write(File.join(root, "drills.json"), JSON.generate(payload))
    described_class.reset!
  end

  after do
    FileUtils.remove_entry(root)
    described_class.reset!
  end

  subject(:drills) { described_class.new(root) }

  it "separates solid sections from thin ones so the UI can say which is which" do
    expect(drills.solid_sections.map { |s| s["id"] }).to(eq(["aspiration"]))
    expect(drills.thin_sections.map { |s| s["id"] }).to(contain_exactly("coda_e", "vowel_a"))
  end

  it "approves only syllables that appear in some section" do
    expect(drills.approves?("gao1")).to(be(true))
    expect(drills.approves?("chen2")).to(be(true))
    expect(drills.approves?("mao2")).to(be(true))
    expect(drills.approves?("zzz9")).to(be(false))
  end

  it "flattens pairs and lists alike when asked for a section's keys" do
    expect(drills.keys_for("aspiration")).to(include("gao1", "kao1", "bi4"))
    expect(drills.keys_for("vowel_a")).to(eq(%w[mao2 hao3 tiao2]))
    expect(drills.keys_for("nope")).to(eq([]))
  end

  it "returns pairs as pairs and list entries as singletons" do
    expect(drills.items_for("aspiration").first).to(eq(%w[gao1 kao1]))
    expect(drills.items_for("vowel_a").first).to(eq(["mao2"]))
  end

  it "reports itself unavailable when no drill file was deployed" do
    described_class.reset!
    expect(described_class.new(Dir.mktmpdir).available?).to(be(false))
  end
end
