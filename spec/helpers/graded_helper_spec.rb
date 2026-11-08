# frozen_string_literal: true

require "rails_helper"

RSpec.describe GradedHelper do
  let(:token) { Data.define(:kind, :text) }
  let(:reading) { Data.define(:zhuyin) }
  let(:tokens) {
    [
      token.new(kind: :word, text: "你好"),
      token.new(kind: :literal, text: "，"),
      token.new(kind: :word, text: "嗎")
    ]
  }

  it "hands back one syllable for every character, leaving out punctuation" do
    line = reading.new(zhuyin: "ㄋㄧˇ ㄏㄠˇ ， ˙ㄇㄚ")

    expect(helper.aligned_syllables(line, tokens)).to(eq(%w[ㄋㄧˇ ㄏㄠˇ ˙ㄇㄚ]))
  end

  it "gives up when the reading does not line up with the characters" do
    expect(helper.aligned_syllables(reading.new(zhuyin: "ㄋㄧˇ ㄏㄠˇ"), tokens)).to(be_nil)
  end

  it "gives up when there is nothing to align" do
    expect(helper.aligned_syllables(nil, tokens)).to(be_nil)
    expect(helper.aligned_syllables(reading.new(zhuyin: "ㄋㄧˇ"), [])).to(be_nil)
  end
end
