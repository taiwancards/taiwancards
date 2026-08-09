# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::PhraseDrillsImporter do
  let(:file) { Rails.root.join("tmp/phrase_drills_test.txt") }

  after { FileUtils.rm_f(file) }

  def write(rows)
    File.write(file, rows.map { |row| row.join("\t") }.join("\n") + "\n")
  end

  it "imports every row as a restricted phrase with both translations, in file order" do
    write([["我好餓。", "I'm hungry.", "Я голоден."], ["你好嗎？", "How are you?", "Как дела?"]])

    result = described_class.new.call(file)

    expect(result).to(eq({imported: 2, retired: 0, linked: 0}))
    first, second = described_class.drills.to_a
    expect(first.text).to(eq("我好餓。"))
    expect(first).to(be_restricted)
    expect(first.meanings).to(eq({"en" => "I'm hungry.", "ru" => "Я голоден."}))
    expect(second.text).to(eq("你好嗎？"))
    expect(second.sources).to(eq([described_class::SOURCE]))
  end

  it "keeps the drills out of sight for everybody but the owner" do
    write([["我好餓。", "I'm hungry.", "Я голоден."]])
    described_class.new.call(file)

    Current.set(user: create(:user)) do
      expect(Lexeme.visible.where(kind: :phrase)).to(be_empty)
    end

    Current.set(user: create(:user, :admin, restricted_content: true)) do
      expect(Lexeme.visible.where(kind: :phrase).count).to(eq(1))
    end
  end

  it "runs twice without duplicating and picks up corrected translations" do
    write([["我好餓。", "I'm hungry.", "Я голоден."]])
    described_class.new.call(file)
    write([["我好餓。", "I'm so hungry.", "Я так проголодался."]])

    result = described_class.new.call(file)

    expect(result).to(eq({imported: 1, retired: 0, linked: 0}))
    expect(Lexeme.where(kind: :phrase).count).to(eq(1))
    expect(Lexeme.find_by(text: "我好餓。").meanings["en"]).to(eq("I'm so hungry."))
  end

  it "retires a sentence that left the file" do
    write([["我好餓。", "I'm hungry.", "Я голоден."], ["你好嗎？", "How are you?", "Как дела?"]])
    described_class.new.call(file)
    write([["我好餓。", "I'm hungry.", "Я голоден."]])

    result = described_class.new.call(file)

    expect(result).to(eq({imported: 1, retired: 1, linked: 0}))
    expect(Lexeme.where(kind: :phrase).pluck(:text)).to(eq(["我好餓。"]))
  end

  it "leaves a textbook phrase alone, only unhooking it from the drills" do
    textbook = create(
      :lexeme,
      kind: :phrase,
      text: "謝謝老師。",
      restricted: true,
      sources: ["Textbook B1L01", described_class::SOURCE],
      data: {"drill" => 5}
    )
    write([["我好餓。", "I'm hungry.", "Я голоден."]])

    described_class.new.call(file)

    expect(textbook.reload.data).not_to(have_key("drill"))
    expect(textbook.sources).to(eq(["Textbook B1L01"]))
  end

  it "grades a sentence on TOCFL and TBCL when the words cover it" do
    create(:lexeme, kind: :word, text: "晚餐", data: {"tocfl_level" => "A2", "tbcl_grade" => 3})
    create(:lexeme, kind: :word, text: "好吃", data: {"tocfl_level" => "A1", "tbcl_grade" => 2})
    Huayu::TextAnalyzer.reset_vocabulary!
    write([["晚餐好吃。", "Dinner is tasty.", "Ужин вкусный."]])

    described_class.new.call(file)

    drill = described_class.drills.first
    expect(drill.data["segments"]).to(eq(%w[晚餐 好吃]))
    expect(drill.data["tocfl"]).to(eq(SentenceProfile::TOCFL_LEVELS.index("A2") + 1))
    expect(drill.data["tocfl_exact"]).to(be(true))
    expect(drill.data["tbcl"]).to(eq(3))
  ensure
    Huayu::TextAnalyzer.reset_vocabulary!
  end

  it "leaves a sentence ungraded when more than five percent of it is unlisted" do
    create(:lexeme, kind: :word, text: "晚餐", data: {"tocfl_level" => "A2"})
    Huayu::TextAnalyzer.reset_vocabulary!
    write([["晚餐好吃。", "Dinner is tasty.", "Ужин вкусный."]])

    described_class.new.call(file)

    expect(described_class.drills.first.data["tocfl"]).to(be_nil)
  ensure
    Huayu::TextAnalyzer.reset_vocabulary!
  end

  it "links a sentence to the dictionary entries it uses, and never the other way around" do
    word = create(:lexeme, kind: :word, text: "晚餐")
    Huayu::TextAnalyzer.reset_vocabulary!
    write([["晚餐。", "Dinner.", "Ужин."]])

    result = described_class.new.call(file)

    drill = described_class.drills.first
    expect(result[:linked]).to(eq(1))
    expect(drill.components).to(eq([word]))
    expect(word.reload.containers).to(be_empty)
    expect(word.containing_words).to(be_empty)
  ensure
    Huayu::TextAnalyzer.reset_vocabulary!
  end

  it "does nothing when the file is absent" do
    expect(described_class.new.call(Rails.root.join("tmp/nope.txt"))).to(eq({imported: 0, retired: 0, linked: 0}))
  end
end
