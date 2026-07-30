# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::SyllableKey do
  def store_with(*keys)
    instance_double(Pronunciation::TemplateStore).tap do |store|
      allow(store).to(receive(:template)) { |key| keys.include?(key) ? {"tone" => 1} : nil }
    end
  end

  it "strips the tone mark instead of gluing it onto the pinyin" do
    target = {"pinyin" => "shǐ", "zhuyin" => "ㄕˇ", "tone" => 3}

    expect(described_class.for(target, store: store_with("shi3"))).to(eq("shi3"))
  end

  it "uses the sandhi tone the learner actually has to produce" do
    target = {"pinyin" => "nǐ", "zhuyin" => "ㄋㄧˇ", "tone" => 2, "base_tone" => 3}

    expect(described_class.for(target, store: store_with("ni2", "ni3"))).to(eq("ni2"))
  end

  it "finds the u spelling when the inventory has no v spelling" do
    target = {"pinyin" => "lǜ", "zhuyin" => "ㄌㄩˋ", "tone" => 4}

    expect(described_class.for(target, store: store_with("lu4"))).to(eq("lu4"))
    expect(described_class.for(target, store: store_with("lv4"))).to(eq("lv4"))
  end

  it "prefers a key the caller supplied when the store has it" do
    target = {"pinyin" => "shǐ", "tone" => 3, "key" => "shi3"}

    expect(described_class.for(target, store: store_with("shi3"))).to(eq("shi3"))
  end

  it "returns its best guess when nothing matches" do
    target = {"pinyin" => "yo", "tone" => 1}

    expect(described_class.for(target, store: store_with)).to(eq("yo1"))
  end

  it "survives a target with no pinyin at all" do
    expect(described_class.for({"tone" => 1}, store: store_with)).to(be_nil)
  end

  describe "the target the dictionary builds" do
    it "carries a key the template store can look up" do
      lexeme = create(:lexeme, kind: :character, text: "屎", readings: {"pinyin" => "shǐ"})

      expect(Huayu::PronunciationTarget.new(lexeme).syllables.first).to(include("key" => "shi3"))
    end
  end
end
