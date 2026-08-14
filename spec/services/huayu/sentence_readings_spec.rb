# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceReadings do
  def reading(sentence)
    described_class.new.call([sentence])[sentence]
  end

  before do
    create(:lexeme, kind: :character, text: "和", readings: {"zhuyin" => "ㄏㄜˊ", "pinyin" => "hé"})
    create(:lexeme, kind: :word, text: "和平", readings: {"zhuyin" => "ㄏㄜˊ ㄆㄧㄥˊ", "pinyin" => "hépíng"})
    create(:lexeme, kind: :word, text: "暖和", readings: {"zhuyin" => "ㄋㄨㄢˇ ˙ㄏㄨㄛ", "pinyin" => "nuǎnhuo"})
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
end
