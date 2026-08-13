# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::GlossOverrideEnricher do
  let(:path) { Rails.root.join("tmp/spec-gloss-overrides-#{SecureRandom.hex(4)}.json") }

  after { path.delete if path.exist? }

  def write(overrides)
    path.dirname.mkpath
    path.write(JSON.generate(overrides))
  end

  it "fills a gloss that is missing" do
    lexeme = Lexeme.create!(kind: :word, text: "冰塊兒", meanings: {})
    write({"冰塊兒" => {"en" => "ice cube", "ru" => "кубик льда"}})

    expect(described_class.new(path:).call).to(include(en: 1, ru: 1))
    expect(lexeme.reload.meanings).to(eq({"en" => "ice cube", "ru" => "кубик льда"}))
  end

  it "leaves a gloss that is already there alone" do
    lexeme = Lexeme.create!(kind: :word, text: "花兒", meanings: {"en" => "flower"})
    write({"花兒" => {"en" => "style of folk song popular in Gansu"}})

    expect(described_class.new(path:).call).to(include(en: 0, replaced_en: 0))
    expect(lexeme.reload.meanings["en"]).to(eq("flower"))
  end

  it "corrects a gloss when the entry asks to replace it" do
    lexeme = Lexeme.create!(kind: :word, text: "刀子", meanings: {"en" => "knife; CL:把[ba3]", "ru" => "нож"})
    write({"刀子" => {"en" => "knife", "replace" => true}})

    expect(described_class.new(path:).call).to(include(replaced_en: 1))
    expect(lexeme.reload.meanings).to(eq({"en" => "knife", "ru" => "нож"}))
  end

  it "leaves measure words to the classifier importer that owns them" do
    word = Lexeme.create!(kind: :word, text: "小時", meanings: {"en" => "hour; CL:個|个[ge4]"})
    classifier = Lexeme.create!(kind: :measure_word, text: "小時", meanings: {"en" => "Counts hours."})
    write({"小時" => {"en" => "hour", "replace" => true}})

    expect(described_class.new(path:).call).to(include(replaced_en: 1))
    expect(word.reload.meanings["en"]).to(eq("hour"))
    expect(classifier.reload.meanings["en"]).to(eq("Counts hours."))
  end

  it "leaves radicals to the radical importer that owns them" do
    character = Lexeme.create!(kind: :character, text: "覀", meanings: {"en" => "west (old form)"})
    radical = Lexeme.create!(kind: :radical, text: "覀", meanings: {"en" => "west"})
    write({"覀" => {"en" => "to cover; west (archaic)", "replace" => true}})

    expect(described_class.new(path:).call).to(include(replaced_en: 1))
    expect(character.reload.meanings["en"]).to(eq("to cover; west (archaic)"))
    expect(radical.reload.meanings["en"]).to(eq("west"))
  end

  it "never empties a side the entry says nothing about" do
    lexeme = Lexeme.create!(kind: :word, text: "上面", meanings: {"en" => "above", "ru" => "сверху"})
    write({"上面" => {"ru" => "сверху; выше", "replace" => true}})

    described_class.new(path:).call
    expect(lexeme.reload.meanings).to(eq({"en" => "above", "ru" => "сверху; выше"}))
  end
end
