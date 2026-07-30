# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CNS11643 reference data" do
  describe Huayu::CnsStrokes do
    it "carries the Taiwan stroke count, which differs from the mainland one" do
      expect(described_class.count("之")).to(eq(4))
      expect(described_class.count("以")).to(eq(5))
    end

    it "decodes a stroke sequence into stroke types" do
      expect(described_class.sequence("一")).to(eq("1"))
      expect(described_class.strokes("之")).to(eq(%i[dian heng pie dian]))
    end

    it "reports divergence against another count" do
      expect(described_class).to(be_diverges("之", 3))
      expect(described_class).not_to(be_diverges("之", 4))
      expect(described_class).not_to(be_diverges("之", nil))
    end

    it "returns nothing for an unknown glyph" do
      expect(described_class.count("Z")).to(be_nil)
      expect(described_class).not_to(be_known("Z"))
    end
  end

  describe Huayu::CnsVoice do
    it "maps zhuyin onto the clip key, with tone one unmarked" do
      expect(described_class.for("ㄋㄧˇ")&.key).to(eq("ni3"))
      expect(described_class.for("ㄅㄚ")&.key).to(eq("ba"))
    end

    it "normalises a trailing neutral mark to the leading Taiwan form" do
      expect(described_class.for("ㄉㄜ˙")&.key).to(eq("de5"))
    end

    it "alternates between the two voices" do
      expect(described_class.alternating("ㄏㄠˇ", 0)&.voice).to(eq("female"))
      expect(described_class.alternating("ㄏㄠˇ", 1)&.voice).to(eq("male"))
    end

    it "refuses a key that does not match the clip pattern" do
      expect(described_class.clip_path("female", "../etc/passwd")).to(be_nil)
      expect(described_class.clip_url("nobody", "ni3")).to(be_nil)
    end

    it "returns nothing for a syllable it does not cover" do
      expect(described_class.for("ㄅㄨㄥˊ")).to(be_nil)
    end
  end
end
