# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceTemplate do
  describe ".tail_key" do
    it "groups sentences that share their closing ten characters" do
      first = described_class.tail_key("前項實施辦法由中央主管機關定之。")
      second = described_class.tail_key("本條例施行細則之辦法由中央主管機關定之。")
      expect(first).to(eq(second))
    end

    it "keeps unrelated sentences apart" do
      expect(described_class.tail_key("前項實施辦法由中央主管機關定之。"))
        .not_to(eq(described_class.tail_key("我們全家打算到山莊避暑消夏歇息。")))
    end

    it "returns nothing for a sentence too short to fingerprint" do
      expect(described_class.tail_key("我知道了。")).to(be_nil)
    end
  end

  describe ".digit_key" do
    it "groups sentences that differ only in their numbers" do
      expect(described_class.digit_key("違反第十二條第三項規定。"))
        .to(eq(described_class.digit_key("違反第四十條第一項規定。")))
    end

    it "returns nothing when there is no number to normalize" do
      expect(described_class.digit_key("我知道你在想什麼")).to(be_nil)
    end
  end
end
