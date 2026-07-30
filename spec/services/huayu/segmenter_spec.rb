# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::Segmenter do
  subject(:segmenter) { described_class.new(%w[請 問 請問 你 好 你好 臺灣 來]) }

  it "prefers the longest known word" do
    expect(segmenter.segment("請問")).to(eq(%w[請問]))
    expect(segmenter.segment("你好")).to(eq(%w[你好]))
  end

  it "segments a sentence into known words and drops unknown characters" do
    expect(segmenter.segment("你好，歡迎來臺灣")).to(eq(%w[你好 來 臺灣]))
  end

  it "falls back to single known characters" do
    expect(segmenter.segment("請你來")).to(eq(%w[請 你 來]))
  end
end
