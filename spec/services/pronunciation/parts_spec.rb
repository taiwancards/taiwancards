# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Parts do
  def ids(zhuyin)
    described_class.describe(zhuyin).to_h { |part| [part["id"], part["zhuyin"]] }
  end

  it "splits a plain initial and rime" do
    expect(ids("ㄍㄠ")).to(eq({"initial" => "ㄍ", "medial" => nil, "final" => "ㄠ"}))
  end

  it "pulls the medial out of a three-symbol syllable" do
    expect(ids("ㄒㄩㄥ")).to(eq({"initial" => "ㄒ", "medial" => "ㄩ", "final" => "ㄥ"}))
  end

  it "treats a lone glide as the rime, not a medial" do
    expect(ids("ㄧ")).to(eq({"initial" => nil, "medial" => nil, "final" => "ㄧ"}))
    expect(ids("ㄨㄛ")).to(eq({"initial" => nil, "medial" => "ㄨ", "final" => "ㄛ"}))
  end

  it "gives the empty rime a cell of its own" do
    final = described_class.describe("ㄓ").last
    expect(final).to(include("present" => true, "empty_rime" => true, "ipa" => "ɻ̩"))
  end

  it "strips tone marks before splitting" do
    expect(ids("ㄐㄧㄠˋ")).to(eq({"initial" => "ㄐ", "medial" => "ㄧ", "final" => "ㄠ"}))
  end

  it "carries pinyin and IPA for each part" do
    initial = described_class.describe("ㄑㄧㄢ").first
    expect(initial).to(include("pinyin" => "q", "ipa" => "tɕʰ"))
  end
end
