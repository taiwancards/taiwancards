# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SimpToTrad do
  it "converts simplified characters found in community lyrics" do
    converted, changed = described_class.convert("再没有時間 小的时候 后来")

    expect(converted).to(eq("再沒有時間 小的時候 後來"))
    expect(changed).to(contain_exactly("没", "时", "后", "来"))
  end

  it "leaves Taiwan traditional text untouched" do
    converted, changed = described_class.convert("臺灣繁體字沒有問題")

    expect(converted).to(eq("臺灣繁體字沒有問題"))
    expect(changed).to(be_empty)
  end

  it "applies the Taiwan-specific override for ambiguous characters" do
    expect(described_class.convert("发").first).to(eq("發"))
    expect(described_class.convert("台").first).to(eq("臺"))
  end

  it "handles blank input" do
    expect(described_class.convert(nil)).to(eq(["", []]))
  end
end
