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

    expect(result).to(eq({imported: 2, retired: 0}))
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

    expect(result).to(eq({imported: 1, retired: 0}))
    expect(Lexeme.where(kind: :phrase).count).to(eq(1))
    expect(Lexeme.find_by(text: "我好餓。").meanings["en"]).to(eq("I'm so hungry."))
  end

  it "retires a sentence that left the file" do
    write([["我好餓。", "I'm hungry.", "Я голоден."], ["你好嗎？", "How are you?", "Как дела?"]])
    described_class.new.call(file)
    write([["我好餓。", "I'm hungry.", "Я голоден."]])

    result = described_class.new.call(file)

    expect(result).to(eq({imported: 1, retired: 1}))
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

  it "does nothing when the file is absent" do
    expect(described_class.new.call(Rails.root.join("tmp/nope.txt"))).to(eq({imported: 0, retired: 0}))
  end
end
