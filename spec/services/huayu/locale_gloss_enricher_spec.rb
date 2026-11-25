# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::LocaleGlossEnricher do
  let(:store) { Rails.root.join("tmp/spec-vi-glosses.json") }
  let(:page) { Rails.root.join("tmp/spec-vi-curated-page.json") }

  after do
    store.delete if store.exist?
    page.delete if page.exist?
  end

  def run(lexemes: {}, senses: {}, radicals: {}, curated: [], locale: "vi")
    store.write(JSON.generate({"lexemes" => lexemes, "senses" => senses, "radicals" => radicals}))
    described_class.new(locale:, path: store, curated: Huayu::CuratedGlosses.new(paths: curated)).call
  end

  it "adds the Vietnamese gloss beside the English and Russian ones" do
    lexeme = create(:lexeme, kind: :word, text: "謝謝", meanings: {"en" => "thank you", "ru" => "спасибо"})

    run(lexemes: {"謝謝" => "cảm ơn"})

    expect(lexeme.reload.meanings).to(eq("en" => "thank you", "ru" => "спасибо", "vi" => "cảm ơn"))
    expect(lexeme.search_text).to(include("cảm ơn"))
  end

  it "writes a German gloss under its own key and leaves the Vietnamese one alone" do
    lexeme = create(:lexeme, kind: :word, text: "謝謝", meanings: {"en" => "thank you", "vi" => "cảm ơn"})
    sense = LexemeSense.create!(lexeme:, position: 0, gloss_zh: "表示感激。", meanings: {"en" => "thanks"})

    run(lexemes: {"謝謝" => "danke"}, locale: "de")

    expect(lexeme.reload.meanings).to(eq("en" => "thank you", "vi" => "cảm ơn", "de" => "danke"))
    expect(sense.reload.meanings["de"]).to(eq("danke"))
  end

  it "reads each language from its own file" do
    expect(described_class.path_for("de").to_s).to(end_with("huayu/de_glosses.json"))
    expect(described_class.path_for(:vi).to_s).to(end_with("huayu/vi_glosses.json"))
    expect(described_class.path_for("id").to_s).to(end_with("huayu/ind_glosses.json"))
  end

  it "reads Indonesian from the ind file by default and writes it under the ind key" do
    lexeme = create(:lexeme, kind: :word, text: "謝謝", meanings: {"en" => "thank you"})
    sense = LexemeSense.create!(lexeme:, position: 0, gloss_zh: "表示感激。", meanings: {"en" => "thanks"})
    store.write(JSON.generate({"lexemes" => {"謝謝" => "terima kasih"}}))
    allow(AppData).to(receive(:path).and_call_original)
    allow(AppData).to(receive(:path).with("huayu/ind_glosses.json").and_return(store))

    described_class.new(locale: "id", curated: Huayu::CuratedGlosses.new(paths: [])).call

    expect(lexeme.reload.meanings).to(eq("en" => "thank you", "ind" => "terima kasih"))
    expect(sense.reload.meanings).to(eq("en" => "thanks", "ind" => "terima kasih"))
    expect(lexeme.meaning(:id)).to(eq("terima kasih"))
  end

  it "keeps an Indonesian gloss that a curated page owns under ind" do
    lexeme = create(:lexeme, kind: :word, text: "超商", meanings: {"en" => "convenience store"})
    page.write(JSON.generate([{"text" => "超商", "id" => 3, "ind" => "minimarket"}]))

    run(lexemes: {"超商" => "toko"}, curated: [page.to_s], locale: "id")

    expect(lexeme.reload.meanings).to(eq("en" => "convenience store", "ind" => "minimarket"))
  end

  it "reports a missing file instead of failing" do
    expect(described_class.new(locale: "de", path: Rails.root.join("tmp/spec-absent-glosses.json")).call)
      .to(include(:error))
  end

  it "fills each sense by its Chinese definition and leaves the others alone" do
    lexeme = create(:lexeme, kind: :character, text: "一", meanings: {"en" => "one"})
    first = LexemeSense.create!(lexeme:, position: 0, gloss_zh: "第一。", meanings: {"en" => "first"})
    second = LexemeSense.create!(lexeme:, position: 1, gloss_zh: "全、滿、整。", meanings: {"en" => "whole"})

    run(lexemes: {"一" => "một"}, senses: {"一" => {"第一。" => "thứ nhất"}})

    expect(first.reload.meanings["vi"]).to(eq("thứ nhất"))
    expect(second.reload.meanings).not_to(have_key("vi"))
  end

  it "finds a sense whose Ministry numbering or synonym mark the store and the database disagree on" do
    lexeme = create(:lexeme, kind: :character, text: "正", meanings: {"en" => "straight"})
    numbered = LexemeSense.create!(lexeme:, position: 0, gloss_zh: "7.數目大於零的。", meanings: {})
    marked = LexemeSense.create!(lexeme:, position: 1, gloss_zh: "居中的。", meanings: {})

    run(senses: {"正" => {"數目大於零的。" => "dương", "居中的。　△中正" => "ở giữa"}})

    expect(numbered.reload.meanings["vi"]).to(eq("dương"))
    expect(marked.reload.meanings["vi"]).to(eq("ở giữa"))
  end

  it "gives a lone sense the gloss of its entry" do
    lexeme = create(:lexeme, kind: :word, text: "便宜", meanings: {"en" => "cheap"})
    sense = LexemeSense.create!(lexeme:, position: 0, gloss_zh: "價錢低。", meanings: {"en" => "cheap"})

    run(lexemes: {"便宜" => "rẻ"})

    expect(sense.reload.meanings["vi"]).to(eq("rẻ"))
  end

  it "leaves a word whose Vietnamese a curated page owns" do
    lexeme = create(:lexeme, kind: :word, text: "超商", meanings: {"vi" => "cửa hàng tiện lợi"})
    page.write(JSON.generate([{"text" => "超商", "vi" => "cửa hàng tiện lợi"}]))

    run(lexemes: {"超商" => "siêu thị"}, curated: [page.to_s])

    expect(lexeme.reload.meanings["vi"]).to(eq("cửa hàng tiện lợi"))
  end

  it "gives a word the Vietnamese of the page that owns it when that page could not write it" do
    lexeme = create(:lexeme, kind: :word, text: "氣", meanings: {"en" => "air, gas"})
    page.write(
      JSON.generate([{"text" => "氣", "en" => "air; a liberty (go)", "vi" => "không khí; khí (cờ vây)"}])
    )

    run(lexemes: {"氣" => "khí, hơi"}, curated: [page.to_s])

    expect(lexeme.reload.meanings).to(eq("en" => "air, gas", "vi" => "không khí; khí (cờ vây)"))
  end

  it "names a radical by its own Vietnamese name, not by the gloss of the character it shares" do
    character = create(:lexeme, kind: :character, text: "力", meanings: {"en" => "power"})
    radical = create(:lexeme, kind: :radical, text: "力", meanings: {"en" => "power"})

    run(lexemes: {"力" => "sức, lực"}, radicals: {"力" => "Lực — sức"})

    expect(character.reload.meanings["vi"]).to(eq("sức, lực"))
    expect(radical.reload.meanings["vi"]).to(eq("Lực — sức"))
  end

  it "never touches a measure word, whose glosses its own importer owns" do
    lexeme = create(:lexeme, kind: :measure_word, text: "張", meanings: {"en" => "sheet"})

    run(lexemes: {"張" => "tấm"})

    expect(lexeme.reload.meanings).not_to(have_key("vi"))
  end
end
