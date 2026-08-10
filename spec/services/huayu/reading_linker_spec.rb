# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingLinker do
  let(:dir) { Pathname(Dir.mktmpdir) }

  let(:cedict) do
    path = dir.join("cedict.json")
    path.write({"校對" => {"pinyin" => "jiào duì"}}.to_json)
    path
  end

  let(:concised) do
    path = dir.join("concised.json")
    path.write(
      [
        {
          "word" => "覺",
          "zhuyin" => "ㄐㄧㄠˋ",
          "pinyin" => "jiào",
          "senses" => [{"definition" => "睡眠。", "collocations" => ["睡午覺"]}]
        }
      ].to_json
    )
    path
  end

  after { dir.rmtree }

  let!(:xiao) do
    create(
      :lexeme,
      :character,
      text: "校",
      readings: {"pinyin" => "xiào", "zhuyin" => "ㄒㄧㄠˋ"},
      data: {
        "readings" => [
          {"pinyin" => "xiào", "zhuyin" => "ㄒㄧㄠˋ"},
          {"pinyin" => "jiào", "zhuyin" => "ㄐㄧㄠˋ"}
        ]
      }
    )
  end

  let!(:jue) do
    create(
      :lexeme,
      :character,
      text: "覺",
      readings: {"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"},
      data: {
        "readings" => [
          {"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"},
          {"pinyin" => "jiào", "zhuyin" => "ㄐㄧㄠˋ"}
        ]
      }
    )
  end

  let!(:wu) { create(:lexeme, :character, text: "午", readings: {"pinyin" => "wǔ", "zhuyin" => "ㄨˇ"}) }

  def word(text, readings, children)
    lexeme = create(:lexeme, kind: :word, text:, readings:)
    children.each_with_index { |child, index| LexemeLink.create!(parent: lexeme, child:, position: index) }
    lexeme
  end

  def link_reading(parent, child)
    LexemeLink.find_by(parent:, child:).reading
  end

  def run
    described_class.new(io: StringIO.new, cedict: cedict, concised: concised).call
  end

  it "takes the reading from the zhuyin syllable standing in the character's place" do
    school = word(
      "學校",
      {"zhuyin" => "ㄒㄩㄝˊ　ㄒㄧㄠˋ"},
      [create(:lexeme, :character, text: "學"), xiao]
    )

    run

    expect(link_reading(school, xiao)).to(eq("xiào"))
  end

  it "falls back to the CC-CEDICT syllables when the word carries no zhuyin" do
    proof = word("校對", {}, [xiao, create(:lexeme, :character, text: "對")])

    run

    expect(link_reading(proof, xiao)).to(eq("jiào"))
  end

  it "uses the dictionary's own examples when the word has no reading at all" do
    nap = word("睡午覺", {}, [create(:lexeme, :character, text: "睡"), wu, jue])

    run

    expect(link_reading(nap, jue)).to(eq("jiào"))
  end

  it "assigns the only reading of a character without asking the word" do
    noon = word("中午", {}, [create(:lexeme, :character, text: "中"), wu])

    run

    expect(link_reading(noon, wu)).to(eq("wǔ"))
  end

  it "leaves the link empty rather than guessing between readings" do
    qing = create(:lexeme, :character, text: "青", readings: {"pinyin" => "qīng", "zhuyin" => "ㄑㄧㄥ"})
    unknown = word("覺青", {}, [jue, qing])

    expect(run).to(include(unresolved: 1))
    expect(link_reading(unknown, jue)).to(be_nil)
  end

  it "clears a reading the character no longer has" do
    qing = create(:lexeme, :character, text: "青", readings: {"pinyin" => "qīng", "zhuyin" => "ㄑㄧㄥ"})
    unknown = word("覺青", {}, [jue, qing])
    LexemeLink.find_by(parent: unknown, child: jue).update_column(:reading, "gǔ")

    expect(run).to(include(cleared: 1))
    expect(link_reading(unknown, jue)).to(be_nil)
  end

  it "still links what it can when the reference dictionaries are missing" do
    school = word("學校", {"zhuyin" => "ㄒㄩㄝˊ　ㄒㄧㄠˋ"}, [create(:lexeme, :character, text: "學"), xiao])

    described_class.new(io: StringIO.new, cedict: dir.join("absent.json"), concised: dir.join("gone.json")).call

    expect(link_reading(school, xiao)).to(eq("xiào"))
  end

  it "reports drift while a character with one reading has an unlinked word" do
    word("中午", {}, [create(:lexeme, :character, text: "中"), wu])

    linker = described_class.new(io: StringIO.new, cedict: cedict, concised: concised)
    expect(linker.drift?).to(be(true))

    linker.call
    expect(described_class.new(io: StringIO.new, cedict: cedict, concised: concised).drift?).to(be(false))
  end

  it "does not call an unresolvable 破音字 link drift" do
    qing = create(:lexeme, :character, text: "青", readings: {"pinyin" => "qīng", "zhuyin" => "ㄑㄧㄥ"})
    word("覺青", {}, [jue, qing])

    run

    expect(described_class.new(io: StringIO.new, cedict: cedict, concised: concised).drift?).to(be(false))
  end
end
