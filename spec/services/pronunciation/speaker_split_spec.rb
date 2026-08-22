# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::Tokens do
  let(:root) { Dir.mktmpdir }
  let(:store) { Pronunciation::TemplateStore.new(root) }

  def token(speaker, key: "ma1")
    {"_key" => key, "_speaker" => speaker, "_index" => 0, "_n_syllables" => 1}
  end

  before do
    described_class.reset!
    allow(Pronunciation::TemplateStore).to(receive(:instance).and_return(store))
    File.write(File.join(root, "test_split.json"), JSON.generate({"held_out_speakers" => %w[stranger]}))
    Dir.mkdir(File.join(root, "tokens"))
    File.write(
      File.join(root, "tokens", "ma1.jsonl"),
      [token("moe_tw"), token("stranger")].map { |row| JSON.generate(row) }.join("\n")
    )
  end

  after do
    described_class.reset!
    FileUtils.remove_entry(root, true)
  end

  it "keeps the held-out voices out of everything that is fitted" do
    speakers = described_class.each("ma1").map { |row| row["_speaker"] }
    expect(speakers).to(eq(%w[moe_tw]))
  end

  it "hands the report exactly the voices no template was built from" do
    speakers = described_class.each("ma1", speakers: :held_out).map { |row| row["_speaker"] }
    expect(speakers).to(eq(%w[stranger]))
  end

  it "can be asked for an explicit set of voices" do
    speakers = described_class.each("ma1", speakers: %w[stranger moe_tw]).map { |row| row["_speaker"] }
    expect(speakers).to(contain_exactly("moe_tw", "stranger"))
  end

  it "reads everything when nothing is held out" do
    File.write(File.join(root, "test_split.json"), JSON.generate({}))
    described_class.reset!
    expect(described_class.each("ma1").count).to(eq(2))
  end
end
