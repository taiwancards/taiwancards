# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Indonesian in the data loaders" do
  after do
    Huayu::CourseLessons.reset!
    Huayu::GrammarLessons.reset!
    MockExam::Bank.reset!
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
          "formula" => {"en" => "A 是 B", "ind" => "A adalah B"},
          "en" => {"title" => "To be", "body" => "body"},
          "ind" => {"title" => "Menjadi – kesamaan"},
          "excluded" => nil,
          "examples" => [{"zh" => "我是學生。", "en" => "I am a student.", "ind" => "Saya pelajar."}]
        },
        {
          "id" => 2,
          "slug" => "bu",
          "pattern" => "不",
          "level" => 1,
          "head" => "不",
          "en" => {"title" => "Not"},
          "examples" => [{"zh" => "我不忙。", "en" => "I am not busy."}]
        }
      ]
    end

    before do
      Huayu::GrammarLessons.reset!
      allow(Huayu::GrammarLessons::DATA).to(receive(:value).and_return(data))
    end

    it "reads Indonesian from ind and never returns the lesson number" do
      lesson = Huayu::GrammarLessons.find("shi")

      expect(lesson.title(:id)).to(eq("Menjadi – kesamaan"))
      expect(lesson.title("id")).to(eq("Menjadi – kesamaan"))
      expect(lesson.body(:id)).to(eq("body"))
      expect(lesson.formula_for(:id)).to(eq("A adalah B"))
      expect(lesson.examples.first.translation(:id)).to(eq("Saya pelajar."))
    end

    it "falls back to English for a lesson without Indonesian" do
      lesson = Huayu::GrammarLessons.find("bu")

      expect(lesson.title(:id)).to(eq("Not"))
      expect(lesson.examples.first.translation(:id)).to(eq("I am not busy."))
    end

    it "finds a lesson by its Indonesian title" do
      expect(Huayu::GrammarLessons.search("kesamaan").map(&:slug)).to(eq(["shi"]))
    end
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
            "ind" => {"title" => "Langkah pertama"}
          }
        ],
        "lessons" => [
          {
            "slug" => "tea",
            "number" => 1,
            "stage" => "novice1",
            "text" => {
              "lines" => [
                {"who" => "安安", "zh" => "我喝茶。", "en" => "I drink tea.", "ind" => "Saya minum teh."}
              ]
            },
            "vocabulary" => [{"zh" => "茶", "en" => "tea", "ind" => "teh"}],
            "usage" => [
              {"street" => "禮拜六", "standard" => "星期六", "en" => "Say 禮拜.", "ind" => "Katakan 禮拜."}
            ]
          }
        ]
      }
    end

    before do
      Huayu::CourseLessons.reset!
      allow(Huayu::CourseLessons::DATA).to(receive(:value).and_return(data))
    end

    it "reads the Indonesian side of stages, lines, words and usage notes" do
      lesson = Huayu::CourseLessons.find("tea")

      expect(Huayu::CourseLessons.stage("novice1").title(:id)).to(eq("Langkah pertama"))
      expect(lesson.lines.first.translation(:id)).to(eq("Saya minum teh."))
      expect(lesson.vocabulary.first.gloss(:id)).to(eq("teh"))
      expect(lesson.usage.first.body(:id)).to(eq("Katakan 禮拜."))
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
              "questions" => [
                {
                  "ask" => "他喝什麼？",
                  "options" => %w[茶 水 酒],
                  "answer" => 0,
                  "en" => "What does he drink?",
                  "ind" => "Apa yang dia minum?",
                  "why_en" => "He says tea.",
                  "why_ind" => "Dia bilang teh."
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

    it "never takes the block identifier for its Indonesian name" do
      block = MockExam::Bank.blocks("Novice1").sole
      question = block.questions.sole

      expect(block.id).to(eq("n1-1"))
      expect(block.names).not_to(have_key("id"))
      expect(block.name(:id)).to(eq("I drink tea."))
      expect([question.ask_name(:id), question.note(:id)]).to(eq(["Apa yang dia minum?", "Dia bilang teh."]))
    end
  end

  describe Huayu::TaiwanNames::Character do
    it "gives the Indonesian meaning of a name character, or the English one without it" do
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
        de: nil,
        ind: "indah",
        ja: nil,
        fields: [],
        cohorts: {},
        lean: nil
      )

      expect(character.meaning(:id)).to(eq("indah"))
      expect(character.with(ind: nil).meaning(:id)).to(eq("beautiful"))
    end
  end
end
