# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Syllables do
  before do
    @dir = Dir.mktmpdir
    keys = {
      "ma1" => {"syllable" => "ma", "tone" => 1, "zhuyin" => "ㄇㄚ"},
      "ma3" => {"syllable" => "ma", "tone" => 3, "zhuyin" => "ㄇㄚˇ"},
      "mo2" => {"syllable" => "mo", "tone" => 2, "zhuyin" => ""}
    }
    File.write(File.join(@dir, "inventory.json"), JSON.dump({"keys" => keys}))
    described_class.load!(File.join(@dir, "inventory.json"))
  end

  after do
    FileUtils.remove_entry(@dir)
    described_class.load!
  end

  it "reads the tones each syllable carries" do
    expect(described_class.tones_for("ma")).to(eq([1, 3]))
    expect(described_class.all_syllables).to(contain_exactly("ma", "mo"))
  end

  it "answers an unknown syllable without growing the tables" do
    syllables = described_class.all_syllables.dup
    spelled = described_class.zhuyin.keys.dup

    expect(described_class.tones_for("zzz")).to(eq([]))
    expect(described_class.zhuyin["ba1"]).to(eq("ㄅㄚ"))
    expect(described_class.zhuyin["nonsense"]).to(be_nil)

    expect(described_class.all_syllables).to(eq(syllables))
    expect(described_class.zhuyin.keys).to(eq(spelled))
  end

  it "spells a key whose stored zhuyin is missing" do
    expect(described_class.zhuyin["mo2"]).to(eq("ㄇㄛˊ"))
    expect(described_class.zhuyin["ma3"]).to(eq("ㄇㄚˇ"))
  end

  it "publishes a table only once it is complete" do
    expect(described_class.instance_variable_get(:@by_syllable)).to(be_frozen)
    expect(described_class.instance_variable_get(:@zhuyin)).to(be_frozen)
  end
end
