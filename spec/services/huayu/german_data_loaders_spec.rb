# frozen_string_literal: true

require "rails_helper"

RSpec.describe "German in the data loaders" do
  after do
    Huayu::CourseLessons.reset!
    Huayu::GrammarLessons.reset!
    MockExam::Bank.reset!
  end

  describe Huayu::CourseLessons do
    let(:data) do
      {
        "stages" => [
          {
            "slug" => "novice1",
            "band" => "TOCFL Novice 1",
            "order" => 1,
            "en" => {"title" => "First steps"},
            "de" => {"title" => "Erste Schritte", "body" => "Grundlagen"}
          }
        ],
        "lessons" => [
          {
            "slug" => "tea",
            "number" => 1,
            "stage" => "novice1",
            "text" => {
              "lines" => [
                {"who" => "安安", "zh" => "我喝茶。", "en" => "I drink tea.", "de" => "Ich trinke Tee."}
              ]
            },
            "vocabulary" => [{"zh" => "茶", "en" => "tea", "de" => "Tee"}, {"zh" => "喝", "en" => "drink"}],
            "usage" => [
              {"street" => "禮拜六", "standard" => "星期六", "en" => "Say 禮拜.", "de" => "Man sagt 禮拜."}
            ]
          }
        ]
      }
    end

    before do
      Huayu::CourseLessons.reset!
      allow(Huayu::CourseLessons::DATA).to(receive(:value).and_return(data))
    end

    it "reads the German side of stages, lines, words and usage notes" do
      stage = Huayu::CourseLessons.stage("novice1")
      lesson = Huayu::CourseLessons.find("tea")

      expect([stage.title(:de), stage.body(:de)]).to(eq(["Erste Schritte", "Grundlagen"]))
      expect(lesson.lines.first.translation(:de)).to(eq("Ich trinke Tee."))
      expect(lesson.vocabulary.map { |word| word.gloss(:de) }).to(eq(%w[Tee drink]))
      expect(lesson.usage.first.body(:de)).to(eq("Man sagt 禮拜."))
      expect(lesson.lines.first.translation(:vi)).to(eq("I drink tea."))
    end
  end

  describe Huayu::GrammarLessons do
    let(:data) do
      [
        {
          "id" => 1,
          "slug" => "shi",
          "pattern" => "是",
          "level" => 1,
          "head" => "是",
          "en" => {"title" => "To be", "body" => "body"},
          "de" => {"title" => "Sein – Gleichsetzung"},
          "examples" => [{"zh" => "我是學生。", "en" => "I am a student.", "de" => "Ich bin Student."}]
        }
      ]
    end

    before do
      Huayu::GrammarLessons.reset!
      allow(Huayu::GrammarLessons::DATA).to(receive(:value).and_return(data))
    end

    it "reads German titles and examples, and falls back to English for the rest" do
      lesson = Huayu::GrammarLessons.find("shi")

      expect(lesson.title(:de)).to(eq("Sein – Gleichsetzung"))
      expect(lesson.body(:de)).to(eq("body"))
      expect(lesson.examples.first.translation(:de)).to(eq("Ich bin Student."))
    end

    it "finds a lesson by its German title" do
      expect(Huayu::GrammarLessons.search("gleichsetzung").map(&:slug)).to(eq(["shi"]))
    end
  end

  describe MockExam::Bank do
    let(:path) { Pathname(Dir.mktmpdir("exam")).join("novice1.json") }

    before do
      path.write(
        JSON.generate(
          "level" => "Novice1",
          "blocks" => [
            {
              "id" => "n1-1",
              "format" => "sentence",
              "zh" => "我喝茶。",
              "en" => "I drink tea.",
              "de" => "Ich trinke Tee.",
              "questions" => [
                {
                  "ask" => "他喝什麼？",
                  "options" => %w[茶 水 酒],
                  "answer" => 0,
                  "en" => "What does he drink?",
                  "de" => "Was trinkt er?",
                  "why_en" => "He says tea.",
                  "why_de" => "Er sagt Tee."
                }
              ]
            }
          ]
        )
      )
      allow(AppData).to(receive(:path).and_call_original)
      allow(AppData).to(receive(:path).with("huayu/exam/novice1.json").and_return(path))
      MockExam::Bank.reset!
    end

    after { FileUtils.remove_entry(path.dirname) }

    it "reads the German names and explanations of a block and its questions" do
      block = MockExam::Bank.blocks("Novice1").sole
      question = block.questions.sole

      expect(block.name(:de)).to(eq("Ich trinke Tee."))
      expect([question.ask_name(:de), question.note(:de)]).to(eq(["Was trinkt er?", "Er sagt Tee."]))
      expect(question.note(:vi)).to(eq("He says tea."))
    end
  end

  describe Huayu::TaiwanNames::Character do
    it "gives the German meaning of a name character, or the English one without it" do
      character = described_class.new(
        text: "美",
        first: 1,
        second: 2,
        count: 3,
        zhuyin: "ㄇㄟˇ",
        pinyin: "měi",
        tone: 3,
        strokes: 9,
        en: "beautiful",
        ru: "красивый",
        vi: nil,
        de: "schön",
        ind: nil,
        ja: nil,
        fields: [],
        cohorts: {},
        lean: nil
      )

      expect(character.meaning(:de)).to(eq("schön"))
      expect(character.with(de: nil).meaning(:de)).to(eq("beautiful"))
    end
  end
end
