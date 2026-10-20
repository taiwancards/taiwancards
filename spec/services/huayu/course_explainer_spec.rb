# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CourseExplainer do
  let(:words) do
    [
      Huayu::CourseLessons::Word.new(
        zh: "晚上",
        zhuyin: "ㄨㄢˇ ˙ㄕㄤ",
        pinyin: "wǎnshang",
        pos: "n.",
        en: "evening",
        ru: "вечер",
        register: "standard",
        note: {"en" => "After dark, until bedtime.", "ru" => "От темноты до сна."}
      )
    ]
  end

  let(:grammar) {
    [
      Huayu::CourseLessons::GrammarRef.new(
        slug: "weekdays",
        note: {"en" => "Sunday is 禮拜天.", "ru" => "Воскресенье — 禮拜天."}
      )
    ]
  }
  let(:usage) {
    [
      Huayu::CourseLessons::Usage.new(
        street: "禮拜六",
        standard: "星期六",
        en: "Say 禮拜 in speech.",
        ru: "В речи — 禮拜."
      )
    ]
  }
  let(:lines) do
    [
      Huayu::CourseLessons::Line.new(
        who: "安安",
        zh: "你禮拜六有空嗎？",
        en: "Free on Saturday?",
        ru: "В субботу свободен?",
        zhuyin: nil,
        pinyin: nil,
        grammar: ["weekdays"]
      )
    ]
  end

  let(:lesson) do
    Huayu::CourseLessons::Lesson.new(
      slug: "time",
      number: 6,
      stage: "novice1",
      zh_title: "",
      title: {},
      goal: {},
      kind: "dialogue",
      lines:,
      vocabulary: words,
      grammar:,
      culture: {},
      usage:,
      exercises: []
    )
  end

  let(:explainer) { described_class.new([lesson]) }

  def task(kind, **fields)
    Huayu::CourseLessons::Exercise.new(
      kind:,
      zh: fields[:zh],
      gloss: {},
      options: fields.fetch(:options, []),
      answer: fields.fetch(:answer, 0),
      chunks: fields.fetch(:chunks, []),
      order: [],
      pairs: []
    )
  end

  it "gives a word task the word with its reading, gloss and note" do
    note = explainer.call(task("reading", options: ["早上", "晚上"], answer: 1), :ru)

    expect([note.kind, note.zh, note.reading, note.body, note.detail]).to(
      eq([:word, "晚上", "ㄨㄢˇ ˙ㄕㄤ · wǎnshang", "вечер", "От темноты до сна."])
    )
  end

  it "explains a sentence task with the teacher's note for the line's grammar point" do
    note = explainer.call(task("order", chunks: %w[你 禮拜 六 有空 嗎]), :en)

    expect([note.kind, note.body]).to(eq([:grammar, "Sunday is 禮拜天."]))
  end

  it "finds the line of a cloze once the blank is filled with the answer" do
    note = explainer.call(task("cloze", zh: "你＿＿六有空嗎？", options: %w[晚上 禮拜], answer: 1), :ru)

    expect(note.body).to(eq("Воскресенье — 禮拜天."))
  end

  it "explains a street task with the usage note" do
    note = explainer.call(task("street", zh: "星期六", options: %w[晚上 禮拜六], answer: 1), :en)

    expect([note.kind, note.zh, note.body]).to(eq([:usage, "星期六 → 禮拜六", "Say 禮拜 in speech."]))
  end

  it "stays silent when there is nothing true to say" do
    expect(explainer.call(task("pair"), :en)).to(be_nil)
    expect(explainer.call(task("order", chunks: %w[我 很 好]), :en)).to(be_nil)
  end
end
