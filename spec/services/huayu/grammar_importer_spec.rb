# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::GrammarImporter do
  def lesson(id:, slug:, pattern:, head:, level: 1, excluded: nil, supplementary: nil)
    Huayu::GrammarLessons::Lesson.new(
      id:,
      slug:,
      pattern:,
      level:,
      head:,
      formula: {"en" => "#{pattern} formula"},
      en: {"title" => "#{slug} in English", "body" => "body", "tip" => "tip"},
      ru: {"title" => "#{slug} по-русски", "body" => "тело", "tip" => "подсказка"},
      examples: [],
      excluded:,
      supplementary:,
      glossary: {}
    )
  end

  it "creates one card per point, in both languages" do
    taught = [lesson(id: 1, slug: "shi", pattern: "繫動詞", head: "是")]
    allow(Huayu::GrammarLessons).to(receive(:taught).and_return(taught))
    allow(Huayu::GrammarLessons).to(receive(:all).and_return(taught))

    result = described_class.new.call
    lexeme = Lexeme.find_by(kind: :grammar, text: "繫動詞")

    expect(result.imported).to(eq(1))
    expect(lexeme.meanings).to(include("en" => "shi in English", "ru" => "shi по-русски"))
    expect(lexeme.data).to(include("grammar_slug" => "shi", "head" => "是", "tbcl_grade" => 1))
  end

  it "keeps two points that share one notation apart" do
    taught = [
      lesson(id: 139, slug: "v-xia-down", pattern: "V下", head: "坐下", level: 3),
      lesson(id: 372, slug: "v-xia-secure", pattern: "V下", head: "下", level: 4)
    ]
    allow(Huayu::GrammarLessons).to(receive(:taught).and_return(taught))
    allow(Huayu::GrammarLessons).to(receive(:all).and_return(taught))

    described_class.new.call

    expect(Lexeme.where(kind: :grammar).pluck(:text)).to(contain_exactly("V下（坐下）", "V下（下）"))
  end

  it "drops a card whose point left the syllabus" do
    stale = create(:lexeme, kind: :grammar, text: "廢棄語法點", data: {"grammar_slug" => "gone"})
    taught = [lesson(id: 1, slug: "shi", pattern: "繫動詞", head: "是")]
    allow(Huayu::GrammarLessons).to(receive(:taught).and_return(taught))
    allow(Huayu::GrammarLessons).to(receive(:all).and_return(taught))

    expect(described_class.new.call.dropped).to(eq(1))
    expect(Lexeme.where(id: stale.id)).to(be_empty)
  end
end
