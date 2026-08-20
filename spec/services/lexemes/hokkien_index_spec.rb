# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::HokkienIndex do
  def loanword
    create(
      :lexeme,
      kind: :word,
      text: "歹勢",
      score: 40,
      readings: {"pinyin" => "dǎishì", "zhuyin" => "ㄉㄞˇ ㄕˋ"},
      meanings: {"en" => "sorry"},
      data: {
        "readings" => [{"pinyin" => "dǎishì", "zhuyin" => "ㄉㄞˇ ㄕˋ"}],
        "hokkien" => {
          "tailo" => "pháinn-sè",
          "reading" => "native",
          "say" => {"zhuyin" => "ㄆㄞˋ ㄙㄝˋ", "pinyin" => "pài sè"}
        }
      }
    )
  end

  it "reports no drift once every loanword carries its Hokkien forms" do
    loanword

    expect(described_class.new.drift?).to(be(false))
  end

  it "puts the Hokkien forms back when the stored index has gone stale" do
    lexeme = loanword
    lexeme.update_column(:search_text, "歹勢")

    expect(described_class.new.drift?).to(be(true))
    expect(described_class.new.call.reindexed).to(eq(1))
    expect(lexeme.reload.search_text).to(include("=paise", "=phainnse"))
  end

  it "leaves words without a Hokkien reading alone" do
    create(
      :lexeme,
      kind: :word,
      text: "學校",
      score: 5,
      readings: {"pinyin" => "xuéxiào", "zhuyin" => "ㄒㄩㄝˊ ㄒㄧㄠˋ"},
      meanings: {"en" => "school"},
      data: {"readings" => [{"pinyin" => "xuéxiào", "zhuyin" => "ㄒㄩㄝˊ ㄒㄧㄠˋ"}]}
    )
      .update_column(:search_text, "學校")

    expect(described_class.new.drift?).to(be(false))
  end
end
