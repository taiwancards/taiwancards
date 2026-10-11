# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceReadings do
  def reading(sentence)
    described_class.new.call([sentence])[sentence]
  end

  before do
    create(
      :lexeme,
      kind: :character,
      text: "和",
      readings: {"zhuyin" => "ㄏㄢˋ", "pinyin" => "hàn"},
      data: {"readings" => [{"zhuyin" => "ㄏㄢˋ", "pinyin" => "hàn"}, {"zhuyin" => "ㄏㄜˊ", "pinyin" => "hé"}]}
    )
    create(:lexeme, kind: :word, text: "溫和", readings: {"zhuyin" => "ㄨㄣ ㄏㄜˊ", "pinyin" => "wēnhé"})
    create(:lexeme, kind: :word, text: "氣候", readings: {"zhuyin" => "ㄑㄧˋ ㄏㄡˋ", "pinyin" => "qìhòu"})
    create(:lexeme, kind: :character, text: "局", readings: {"zhuyin" => "ㄐㄩˊ", "pinyin" => "jú"})
    create(:lexeme, kind: :word, text: "和平", readings: {"zhuyin" => "ㄏㄜˊ ㄆㄧㄥˊ", "pinyin" => "hépíng"})
    create(
      :lexeme,
      kind: :word,
      text: "暖和",
      readings: {"zhuyin" => "ㄋㄨㄢˇ ˙ㄏㄨㄛ", "pinyin" => "nuǎnhuo"}
    )
    create(:lexeme, kind: :character, text: "我", readings: {"zhuyin" => "ㄨㄛˇ", "pinyin" => "wǒ"})
    create(:lexeme, kind: :character, text: "你", readings: {"zhuyin" => "ㄋㄧˇ", "pinyin" => "nǐ"})
    Huayu::TextAnalyzer.reset_vocabulary!
  end

  after { Huayu::TextAnalyzer.reset_vocabulary! }

  it "reads a joining 和 as hàn, the way Taiwan says it" do
    line = reading("我和你")

    expect(line.zhuyin).to(include("ㄏㄢˋ"))
    expect(line.pinyin).to(include("hàn"))
    expect(line.pinyin).not_to(include("hé"))
  end

  it "leaves 和 alone inside a word that has its own reading" do
    expect(reading("和平").pinyin).to(eq("hépíng"))
    expect(reading("暖和").pinyin).to(eq("nuǎnhuo"))
  end

  it "reads a phrase without its own entry through the words inside it, and a leftover 和 as in words" do
    analyzer = instance_double(Huayu::TextAnalyzer)
    allow(analyzer).to(receive(:segment)) { |text| [text] }
    readings = described_class.new(analyzer:)

    expect(readings.call(["氣候溫和"])["氣候溫和"].pinyin).to(eq("qìhòuwēnhé"))
    expect(readings.call(["和局"])["和局"].pinyin).to(eq("héjú"))
  end
end
