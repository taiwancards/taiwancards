# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reading hints on a grammar page" do
  it "offers both scripts by name in the interface language, zhuyin already on" do
    get("/ru/grammar/a-not-a")

    expect(response.body).to(include("Чжуинь"))
    expect(response.body).to(include("Пиньинь"))
    expect(response.body).not_to(include("注音"))
    expect(response.body).to(include("reading-hints hints-zhuyin"))
    expect(response.body).not_to(include("hints-pinyin"))
  end

  it "names them in English on an English page" do
    get("/en/grammar/a-not-a")

    expect(response.body).to(include(">Zhuyin<"))
    expect(response.body).to(include(">Pinyin<"))
  end

  it "starts with zhuyin on for a level 5 point too" do
    lesson = Huayu::GrammarLessons.taught.find { |row| row.level == 5 }

    get("/ru/grammar/#{lesson.slug}")

    expect(response.body).to(include("reading-hints hints-zhuyin"))
  end

  it "keeps the pinyin off the page out of the global preference's reach" do
    get("/ru/grammar/a-not-a")

    expect(response.body).to(include("py-line"))
    expect(response.body).not_to(match(/class="pinyin py-line"/))
    expect(response.body).not_to(match(/class="pinyin py-reading"/))
  end
end

RSpec.describe "Chinese inside a grammar explanation" do
  def blocks_of(text, lesson)
    view = ActionView::Base.empty.tap { |base| base.extend(GrammarHelper) }
    view.send(:grammar_blocks, text)
  end

  let(:lesson) { Huayu::GrammarLessons.find("a-not-a") }

  it "pulls anything longer than three characters onto a line of its own" do
    kinds = blocks_of(lesson.body(:ru), lesson).map(&:first)

    expect(kinds).to(include(:example))
    expect(blocks_of(lesson.body(:ru), lesson).select { |kind, _| kind == :example }.map { |_, zh| zh })
      .to(include("你喜不喜歡咖啡？"))
  end

  it "leaves one, two and three characters inside the sentence" do
    prose = blocks_of(lesson.body(:ru), lesson).select { |kind, _| kind == :prose }.map { |_, text| text }.join(" ")

    expect(prose).to(include("不"))
    expect(prose).to(include("嗎"))
    expect(prose).to(include("不喜歡"))
  end

  it "gives every pulled-out line a zhuyin and a pinyin reading" do
    Huayu::GrammarLessons.taught.each do |row|
      [row.body(:ru), row.body(:en), row.tip(:ru), row.tip(:en)].compact_blank.each do |text|
        blocks_of(text, row).each do |kind, zh, _gloss, _note|
          next unless kind == :example

          reading = (row.reading(zh) || row.reading(zh.gsub(/\P{Han}/, ""))).to_h
          expect(reading["zhuyin"]).to(be_present, "#{row.slug}: #{zh} has no zhuyin")
          expect(reading["pinyin"]).to(be_present, "#{row.slug}: #{zh} has no pinyin")
        end
      end
    end
  end

  it "never strands the rest of a sentence as its own paragraph" do
    Huayu::GrammarLessons.taught.each do |row|
      [row.body(:ru), row.body(:en), row.tip(:ru), row.tip(:en)].compact_blank.each do |text|
        blocks_of(text, row).each_cons(2) do |(kind, *), (next_kind, next_text, *)|
          next unless kind == :example && next_kind == :prose

          expect(next_text).not_to(match(/\A[[:lower:]]/), "#{row.slug}: “#{next_text.truncate(40)}” is a leftover")
        end
      end
    end
  end
end
