# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SenseImporter do
  let!(:source) do
    ContentSource.find_by(slug: "moe_concised") ||
      ContentSource.create!(
        slug: "moe_concised",
        license_commercial: true,
        name: "MOE",
        enabled: true,
        enabled_for_admins: true,
        attribution: "MOE."
      )
  end

  let(:dir) { Pathname(Dir.mktmpdir) }

  let(:path) do
    file = dir.join("concised.json")
    file.write(
      [
        {
          "word" => "覺",
          "zhuyin" => "ㄐㄧㄠˋ",
          "pinyin" => "jiào",
          "senses" => [{"definition" => "睡眠。", "collocations" => ["睡覺"]}]
        },
        {
          "word" => "覺",
          "zhuyin" => "ㄐㄩㄝˊ",
          "pinyin" => "jué",
          "senses" => [{"definition" => "感受到。"}, {"definition" => "知覺。"}]
        },
        {"word" => "貓", "zhuyin" => "ㄇㄠ", "pinyin" => "māo", "senses" => [{"definition" => "動物名。"}]}
      ].to_json
    )
    file
  end

  after { dir.rmtree }

  def import
    described_class.new(path:, io: StringIO.new).call
  end

  it "keeps every reading of a 破音字 instead of the last one in the file" do
    lexeme = create(
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

    import

    senses = lexeme.senses.ordered
    expect(senses.map(&:reading)).to(eq(%w[jué jué jiào]))
    expect(senses.map(&:gloss_zh)).to(eq(["感受到。", "知覺。", "睡眠。"]))
  end

  it "follows the reading order of the character it is importing into" do
    lexeme = create(
      :lexeme,
      :character,
      text: "覺",
      readings: {"pinyin" => "jiào", "zhuyin" => "ㄐㄧㄠˋ"},
      data: {
        "readings" => [
          {"pinyin" => "jiào", "zhuyin" => "ㄐㄧㄠˋ"},
          {"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"}
        ]
      }
    )

    import

    expect(lexeme.senses.ordered.map(&:reading)).to(eq(%w[jiào jué jué]))
  end

  it "leaves the reading empty when the character has only one" do
    lexeme = create(:lexeme, :character, text: "貓", readings: {"pinyin" => "māo", "zhuyin" => "ㄇㄠ"})

    import

    expect(lexeme.senses.ordered.map(&:reading)).to(eq([nil]))
  end
end
