# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingImporter do
  let(:dir) { Pathname(Dir.mktmpdir) }

  let(:concised) do
    path = dir.join("concised.json")
    path.write(
      [
        {"word" => "覺", "zhuyin" => "ㄐㄧㄠˋ", "pinyin" => "jiào", "senses" => [{"definition" => "睡眠。"}]},
        {
          "word" => "覺",
          "zhuyin" => "ㄐㄩㄝˊ",
          "pinyin" => "jué",
          "senses" => [{"definition" => "感受到。"}, {"definition" => "知覺。"}, {"definition" => "先覺。"}]
        },
        {"word" => "企", "zhuyin" => "ㄑㄧˋ", "pinyin" => "qì", "senses" => [{"definition" => "踮起腳跟。"}]}
      ].to_json
    )
    path
  end

  let(:revised) do
    path = dir.join("revised.json")
    path.write(
      [
        {
          "title" => "唭",
          "heteronyms" => [{"bopomofo" => "ㄑㄧˊ", "pinyin" => "qí", "definitions" => [{"def" => "笑聲。"}]}]
        }
      ].to_json
    )
    path
  end

  after { dir.rmtree }

  def import
    described_class.new(io: StringIO.new, concised: concised, revised: revised).call
  end

  def character(text, readings)
    create(:lexeme, :character, text:, readings:)
  end

  it "collects every MOE reading of a 破音字 and keeps the canonical one in front" do
    lexeme = character("覺", {"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"})

    import

    expect(lexeme.reload.reading_set).to(
      eq([{"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"}, {"pinyin" => "jiào", "zhuyin" => "ㄐㄧㄠˋ"}])
    )
    expect(lexeme.readings).to(eq({"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"}))
  end

  it "orders the remaining readings by how many senses the dictionary gives them" do
    lexeme = character("覺", {})

    import

    expect(lexeme.reload.reading_set.map { |reading| reading["zhuyin"] }).to(eq(%w[ㄐㄩㄝˊ ㄐㄧㄠˋ]))
  end

  it "drops a reading the learner dictionary does not list" do
    lexeme = character("企", {"pinyin" => "qǐ", "zhuyin" => "ㄑㄧˇ"})

    expect(import).to(include(replaced: 1))
    expect(lexeme.reload.reading_set).to(eq([{"pinyin" => "qì", "zhuyin" => "ㄑㄧˋ"}]))
  end

  it "falls back to the revised dictionary for characters the learner edition skips" do
    lexeme = character("唭", {})

    import

    expect(lexeme.reload.reading_set).to(eq([{"pinyin" => "qí", "zhuyin" => "ㄑㄧˊ"}]))
  end

  it "keeps a reading of its own when no MOE dictionary carries the character" do
    lexeme = character("々", {"pinyin" => "x", "zhuyin" => "ㄒ"})

    import

    expect(lexeme.reload.reading_set).to(eq([{"pinyin" => "x", "zhuyin" => "ㄒ"}]))
  end
end
