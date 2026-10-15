# frozen_string_literal: true

require "rails_helper"

RSpec.describe Textbook::LexemeImporter do
  before do
    TextbookLesson.create!(
      book: 1,
      lesson: 1,
      title_en: "Welcome!",
      title_zh: "歡迎！",
      vocabulary: [
        {
          "name" => "w1",
          "traditional" => "電腦",
          "pinyin" => "diànnǎo",
          "meaning" => "computer",
          "meaning_ru" => "компьютер",
          "category" => "N",
          "audio" => "B1L01-01.mp3"
        },
        {
          "name" => "w2",
          "traditional" => "請",
          "pinyin" => "qǐng",
          "meaning" => "please",
          "meaning_ru" => "пожалуйста",
          "category" => "V",
          "audio" => "B1L01-02.mp3"
        },
        {
          "name" => "w3",
          "traditional" => "問",
          "pinyin" => "wèn",
          "meaning" => "to ask",
          "meaning_ru" => "спрашивать",
          "category" => "V",
          "audio" => nil
        },
        {
          "name" => "p1",
          "traditional" => "請問",
          "pinyin" => nil,
          "meaning" => "Excuse me",
          "meaning_ru" => "Извините",
          "category" => "Ph",
          "audio" => "B1L01-03.mp3"
        }
      ]
    )
  end

  it "creates character/word/phrase lexemes with readings, meanings, audio and sources" do
    described_class.new.call

    computer = Lexeme.find_by!(kind: :word, text: "電腦")
    expect(computer.reading("zhuyin")).to(eq("ㄉㄧㄢˋ ㄋㄠˇ"))
    expect(computer.meanings).to(eq({"en" => "computer", "ru" => "компьютер"}))
    expect(computer.audio_url).to(eq("/textbook/audio/B1L01-01.mp3"))
    expect(computer.sources).to(eq(["Textbook B1L01"]))
    expect(computer.components.pluck(:kind, :text)).to(eq([%w[character 電], %w[character 腦]]))

    expect(Lexeme.where(kind: :character).pluck(:text)).to(contain_exactly("電", "腦", "請", "問"))
  end

  it "links a phrase to its component words via segmentation" do
    described_class.new.call

    phrase = Lexeme.find_by!(kind: :phrase, text: "請問")
    expect(phrase.components.where(kind: :word).pluck(:text)).to(contain_exactly("請", "問"))
    expect(phrase.audio_url).to(eq("/textbook/audio/B1L01-03.mp3"))
  end

  it "tracks which words contain a character" do
    described_class.new.call

    char = Lexeme.find_by!(kind: :character, text: "請")
    expect(char.containing_words.pluck(:text)).to(contain_exactly("請"))
  end

  it "builds one lesson collection holding the lesson lexemes and is idempotent" do
    importer = described_class.new
    importer.call
    expect { described_class.new.call }.not_to(change(Lexeme, :count))

    collection = Collection.find_by!(name: "Textbook B1L01 · Welcome!")
    expect(collection.kind).to(eq("lesson"))
    expect(collection.lexemes.pluck(:text)).to(contain_exactly("電腦", "請", "問", "請問"))
  end

  context("with readings the textbook writes loosely") do
    before do
      TextbookLesson.create!(
        book: 6,
        lesson: 8,
        title_en: "Variants",
        vocabulary: [
          {
            "name" => "v1",
            "traditional" => "那邊",
            "pinyin" => "nàbiān / nèibiān",
            "meaning" => "over there",
            "category" => "N"
          },
          {
            "name" => "v2",
            "traditional" => "（台）斤",
            "pinyin" => "(Tái) jīn",
            "meaning" => "catty",
            "category" => "M"
          },
          {
            "name" => "v3",
            "traditional" => "有/無福消受",
            "pinyin" => "yǒu/wúfú xiāoshòu",
            "meaning" => "be fortunate enough to enjoy, not have the fortune of enjoying",
            "category" => "Id",
            "variants" => {
              "有福消受" => {"pinyin" => "yǒufú xiāoshòu", "meaning" => "to be lucky enough to enjoy"},
              "無福消受" => {"pinyin" => "wúfú xiāoshòu", "meaning" => "not lucky enough to enjoy"}
            }
          }
        ]
      )
    end

    it "takes the first of two spoken readings" do
      described_class.new.call

      expect(Lexeme.find_by!(text: "那邊").readings).to(
        eq({"pinyin" => "nàbiān", "zhuyin" => "ㄋㄚˋ ㄅㄧㄢ"})
      )
    end

    it "reads through brackets for the zhuyin" do
      described_class.new.call

      expect(Lexeme.find_by!(text: "（台）斤").reading("zhuyin")).to(eq("ㄊㄞˊ ㄐㄧㄣ"))
    end

    it "gives each slashed spelling its own reading and meaning" do
      described_class.new.call

      lucky = Lexeme.find_by!(text: "有福消受")
      unlucky = Lexeme.find_by!(text: "無福消受")
      expect(lucky.reading("zhuyin")).to(eq("ㄧㄡˇ ㄈㄨˊ ㄒㄧㄠ ㄕㄡˋ"))
      expect(unlucky.reading("zhuyin")).to(eq("ㄨˊ ㄈㄨˊ ㄒㄧㄠ ㄕㄡˋ"))
      expect(lucky.meanings["en"]).to(eq("to be lucky enough to enjoy"))
      expect(unlucky.meanings["en"]).to(eq("not lucky enough to enjoy"))
    end
  end

  context("with a character that has more than one reading") do
    before do
      TextbookLesson.create!(
        book: 1,
        lesson: 2,
        title_en: "Readings",
        vocabulary: [
          {
            "name" => "m1",
            "traditional" => "長大",
            "pinyin" => "zhǎngdà",
            "meaning" => "grow up",
            "category" => "V"
          },
          {
            "name" => "m2",
            "traditional" => "延長",
            "pinyin" => "yáncháng",
            "meaning" => "extend",
            "category" => "V"
          }
        ]
      )
    end

    it "keeps every reading and links each word to the reading it uses" do
      described_class.new.call

      char = Lexeme.find_by!(kind: :character, text: "長")
      expect(char.reading_set.map { |r| r["pinyin"] }).to(contain_exactly("zhǎng", "cháng"))
      expect(char.words_for_reading("zhǎng").pluck(:text)).to(eq(["長大"]))
      expect(char.words_for_reading("cháng").pluck(:text)).to(eq(["延長"]))
    end
  end
end
