# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ChinaGuard do
  before { described_class.reset! }

  after { described_class.reset! }

  it "reads a final 兒 as the mainland suffix it is" do
    %w[餡兒 打水漂兒 臉蛋兒].each do |word|
      expect(described_class.offender(word)).to(be_present, "expected #{word} to be flagged")
    end
  end

  it "leaves 兒 alone when it is a word of its own rather than a suffix" do
    %w[託兒所 兒虐 兒息 兒童 自閉兒日托中心].each do |word|
      expect(described_class.offender(word)).to(be_nil, "expected #{word} to pass")
    end
  end

  it "still catches a mainland word that has nothing to do with 兒" do
    expect(described_class.offender("鼠標")).to(be_present)
    expect(described_class.offender("裏頭")).to(be_present)
  end

  it "passes the Taiwanese form of the same idea" do
    expect(described_class.offender("滑鼠")).to(be_nil)
    expect(described_class.offender("裡面")).to(be_nil)
  end
end
