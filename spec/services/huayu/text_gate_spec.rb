# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TextGate do
  subject(:gate) { described_class.instance }

  before { described_class.reset! }

  describe "the policy this application applies" do
    it "imposes no length or density bound, unlike the corpus policy" do
      expect(gate.call("好")).to(be_ok)
    end

    it "admits 裏着衞 because they are listed in the MOE exception chart" do
      expect(gate.call("那裏")).to(be_ok)
      expect(TWFilter.keep?("那裏", policy: TWFilter::Policy.corpus)).to(be(false))
    end

    it "applies the strict punctuation inventory" do
      expect(gate.call("今天很好～").reason).to(eq(:junk))
      expect(TWFilter.keep?("今天很好～很好", policy: TWFilter::Policy.corpus)).to(be(true))
    end

    it "rejects China subject matter, which the corpus policy only marks" do
      expect(gate.call("北京的天氣很冷").reason).to(eq(:china))
      expect(TWFilter.examine("北京的天氣很冷").marks.map(&:code)).to(
        include(:foreign_topic).or(include(:prc_topic))
      )
    end
  end

  describe "the verdict it exposes" do
    it "renames every gem finding code onto its own reason vocabulary" do
      expect(gate.call("値得思考").reason).to(eq(:unlisted))
      expect(gate.call("LINE Pay").reason).to(eq(:no_han))
      expect(gate.call("一點兒").reason).to(eq(:china))
      expect(gate.call("").reason).to(eq(:empty))
    end

    it "reports the offending detail alongside the reason" do
      verdict = gate.call("値得思考")

      expect(verdict).to(be_rejected)
      expect(verdict.offender).to(eq("値"))
      expect(verdict.tier).to(be_nil)
    end

    it "carries the character tier when the text passes" do
      verdict = gate.call("我喜歡吃飯")

      expect(verdict).to(be_ok)
      expect(verdict.tier).to(eq(Huayu::CharacterTiers::COMMON))
      expect(verdict.offender).to(be_nil)
    end
  end

  describe "database markers" do
    after do
      ChinaMarker.delete_all
      Huayu::ChinaGuard.reset!
    end

    it "adds to the gem tables rather than replacing them" do
      ChinaMarker.create!(word: "測試詞", taiwan_form: "測試", band: :hard, active: true)
      Huayu::ChinaGuard.reset!

      expect(gate.call("這是測試詞的例子").reason).to(eq(:china), "the stored marker is applied")
      expect(gate.call("請把這個信息轉發").reason).to(eq(:china), "the gem table still applies")
    end

    it "detects the gem terms through the gem, not through the stored markers" do
      ChinaMarker.create!(word: "測試詞", taiwan_form: "測試", band: :hard, active: true)
      Huayu::ChinaGuard.reset!

      expect(Huayu::ChinaGuard.marker?("信息")).to(be(false))
      expect(Huayu::ChinaGuard.marker?("測試詞")).to(be(true))
    end

    it "sees a marker added after the gate was built once the marker cache is reset" do
      expect(gate.call("這是新標記詞的例子")).to(be_ok)

      ChinaMarker.create!(word: "新標記詞", taiwan_form: "標記", band: :hard, active: true)
      ChinaMarker.reset_cache!

      expect(gate.call("這是新標記詞的例子").reason).to(eq(:china))
    end

    it "ignores markers banded soft or deactivated" do
      ChinaMarker.create!(word: "軟標記", taiwan_form: "標記", band: :soft, active: true)
      ChinaMarker.create!(word: "停用詞", taiwan_form: "停用", band: :hard, active: false)
      Huayu::ChinaGuard.reset!

      expect(gate.call("這是軟標記的例子")).to(be_ok)
      expect(gate.call("這是停用詞的例子")).to(be_ok)
    end
  end
end
