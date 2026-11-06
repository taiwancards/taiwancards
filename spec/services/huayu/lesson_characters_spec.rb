# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::LessonCharacters do
  let(:word) { Data.define(:zh, :zhuyin) }
  let(:lesson) { Data.define(:slug, :vocabulary) { def words = vocabulary.map(&:zh) } }
  let(:first) { lesson.new(slug: "one", vocabulary: [word.new(zh: "你好", zhuyin: "ㄋㄧˇ ㄏㄠˇ")]) }
  let(:second) do
    lesson.new(
      slug: "two",
      vocabulary: [word.new(zh: "媽媽", zhuyin: "ㄇㄚ ˙ㄇㄚ"), word.new(zh: "好", zhuyin: "ㄏㄠˋ")]
    )
  end

  before do
    create(
      :lexeme,
      kind: :character,
      text: "媽",
      readings: {"zhuyin" => "ㄇㄚ"},
      meanings: {"en" => "mother, mom", "vi" => "mẹ"},
      data: {
        "freq_rank" => 300,
        "etymology" => {"type" => "pictophonetic", "semantic" => "女", "phonetic" => "馬", "hint" => "woman"},
        Huayu::EtymologyTranslations::KEY => {"ru" => {"hint" => "женщина"}}
      }
    )
    create(:lexeme, kind: :character, text: "女", meanings: {"en" => "woman, female", "vi" => "phụ nữ; nữ"})
    create(
      :lexeme,
      kind: :character,
      text: "好",
      data: {"freq_rank" => 10, "etymology" => {"type" => "ideographic", "hint" => "A woman 女 with a son 子"}}
    )
  end

  def entries(locale) = described_class.new(second, lessons: [first, second], locale:).call

  it "shows only the characters the lesson is the first to bring in" do
    expect(entries(:en).map(&:text)).to(eq(["媽"]))
  end

  it "reads a character the way the lesson's own word reads it and names that word" do
    entry = entries(:en).sole

    expect(entry.zhuyin).to(eq("ㄇㄚ"))
    expect(entry.word).to(eq("媽媽"))
  end

  it "puts the meaning of a phono-semantic character's meaning part next to that part" do
    expect(entries(:en).sole).to(have_attributes(semantic: "女", semantic_gloss: "woman", phonetic: "馬", hint: nil))
    expect(entries(:ru).sole.semantic_gloss).to(eq("женщина"))
    expect(entries(:vi).sole.semantic_gloss).to(eq("phụ nữ"))
  end

  it "never falls back to an English hint on another language's page" do
    from_scratch = lesson.new(slug: "zero", vocabulary: [word.new(zh: "好", zhuyin: "ㄏㄠˇ")])

    english = described_class.new(from_scratch, lessons: [from_scratch], locale: :en).call.sole
    vietnamese = described_class.new(from_scratch, lessons: [from_scratch], locale: :vi).call.sole

    expect(english.hint).to(eq("A woman 女 with a son 子"))
    expect(vietnamese.hint).to(be_nil)
  end

  it "keeps the most frequent characters when a lesson brings in more than fit" do
    texts = Array.new(described_class::LIMIT + 2) { |index| (0x4E00 + index).chr(Encoding::UTF_8) }
    texts.each_with_index do |text, index|
      create(
        :lexeme,
        kind: :character,
        text:,
        data: {"freq_rank" => 1000 - index, "etymology" => {"type" => "pictographic"}}
      )
    end

    busy = lesson.new(slug: "busy", vocabulary: texts.map { |text| word.new(zh: text, zhuyin: "ㄧ") })

    shown = described_class.new(busy, lessons: [busy], locale: :en).call.map(&:text)

    expect(shown).to(eq(texts.last(described_class::LIMIT)))
  end
end
