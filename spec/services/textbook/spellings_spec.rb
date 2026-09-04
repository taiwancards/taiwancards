# frozen_string_literal: true

require "rails_helper"

RSpec.describe Textbook::Spellings do
  it "leaves an ordinary word alone" do
    expect(described_class.of("學校")).to(eq(["學校"]))
  end

  it "reads the slash as one character standing in for another" do
    expect(described_class.of("唐朝/代")).to(eq(%w[唐朝 唐代]))
  end

  it "handles an alternation that opens the word" do
    expect(described_class.of("有/無福消受")).to(eq(%w[有福消受 無福消受]))
  end

  it "handles an alternation that closes the word" do
    expect(described_class.of("鍥而不舍/捨")).to(eq(%w[鍥而不舍 鍥而不捨]))
  end

  it "expands every alternation it finds" do
    expect(described_class.of("有/無福/祿")).to(eq(%w[有福 有祿 無福 無祿]))
  end

  it "answers nothing for a blank entry" do
    expect(described_class.of(nil)).to(eq([]))
    expect(described_class.of("  ")).to(eq([]))
  end

  it "answers nothing when the slash stands alone" do
    expect(described_class.of("/")).to(eq([]))
  end
end
