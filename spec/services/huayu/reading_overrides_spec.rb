# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingOverrides do
  let(:ping) { {"pinyin" => "píng", "zhuyin" => "ㄆㄧㄥˊ"} }
  let(:feng) { {"pinyin" => "féng", "zhuyin" => "ㄈㄥˊ"} }
  let(:entries) do
    [
      {"text" => "平", "kinds" => ["word"], "readings" => [ping]},
      {"text" => "馮", "kinds" => ["character"], "readings" => [feng, ping]},
      {
        "text" => "萎縮",
        "kinds" => ["word"],
        "readings" => [{"pinyin" => "wēisuō", "zhuyin" => "ㄨㄟ ㄙㄨㄛ"}]
      }
    ]
  end

  let!(:flat) do
    create(:lexeme, kind: :word, text: "平", readings: {"pinyin" => "pián", "zhuyin" => "ㄆㄧㄢˊ"}, data: {})
  end

  let!(:surname) do
    create(:lexeme, :character, text: "馮", readings: ping, data: {"readings" => [ping]})
  end

  def overrides = described_class.new(entries:, io: StringIO.new)

  it "sets the headline and the list of a word" do
    overrides.call

    flat.reload
    expect(flat.readings).to(eq(ping))
    expect(flat.data["readings"]).to(eq([ping]))
  end

  it "sets the headline and the list of a character" do
    overrides.call

    surname.reload
    expect(surname.readings).to(eq(feng))
    expect(surname.data["readings"]).to(eq([feng, ping]))
  end

  it "keeps the override's spelling over a stored one that differs only in spacing" do
    shrink = create(
      :lexeme,
      kind: :word,
      text: "萎縮",
      readings: {"pinyin" => "wēi suō", "zhuyin" => "ㄨㄟ ㄙㄨㄛ"},
      data: {"readings" => [{"pinyin" => "wēi suō", "zhuyin" => "ㄨㄟ ㄙㄨㄛ"}]}
    )

    overrides.call

    expect(shrink.reload.readings["pinyin"]).to(eq("wēisuō"))
  end

  it "is idempotent and reports no drift once applied" do
    expect(overrides.drift?).to(be(true))
    expect(overrides.call.rewritten).to(eq(2))
    expect(overrides.drift?).to(be(false))
    expect(overrides.call.rewritten).to(eq(0))
  end

  it "leaves a row of another kind with the same text alone" do
    character = create(
      :lexeme,
      :character,
      text: "平",
      readings: {"pinyin" => "pián", "zhuyin" => "ㄆㄧㄢˊ"},
      data: {"readings" => [{"pinyin" => "pián", "zhuyin" => "ㄆㄧㄢˊ"}]}
    )

    overrides.call

    expect(character.reload.readings["pinyin"]).to(eq("pián"))
  end

  it "prints a one-line summary" do
    io = StringIO.new
    described_class.new(entries:, io:).call

    expect(io.string.lines.size).to(eq(1))
  end

  it "reads the entries of one kind from the data file" do
    expect(described_class.for_kind(:character).fetch("馮").first["pinyin"]).to(eq("féng"))
  end
end
