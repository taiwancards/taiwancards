# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::Manifest do
  let(:manifest) { described_class.new }

  def token(pinyin, index)
    {"pinyin" => pinyin, "index" => index, "path" => "data/corpus_tw/audio/x.wav"}
  end

  it "keeps a key that agrees with the reading it was measured from" do
    expect(manifest.settle("lu4", token("mǎ lù", 1))).to(eq("lu4"))
  end

  it "keeps the tone the corpus recorded, because it is the tone that was spoken" do
    expect(manifest.settle("wo2", token("wǒ hǎo", 0))).to(eq("wo2"))
    expect(manifest.settle("bu2", token("bù shì", 0))).to(eq("bu2"))
  end

  it "corrects a rime that was written as u where the reading says ü" do
    expect(manifest.settle("lu4", token("fǎ lǜ", 1))).to(eq("lv4"))
    expect(manifest.settle("nu3", token("nǚ ér", 0))).to(eq("nv3"))
  end

  it "corrects a syllable boundary drawn in the wrong place" do
    expect(manifest.settle("ken3", token("kě néng", 0))).to(eq("ke3"))
    expect(manifest.settle("eng2", token("kě néng", 1))).to(eq("neng2"))
  end

  it "leaves a token alone when its reading cannot be parsed" do
    expect(manifest.settle("ba1", token("", 0))).to(eq("ba1"))
    expect(manifest.settle("ba1", token("bā", 7))).to(eq("ba1"))
  end
end
