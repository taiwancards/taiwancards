# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ViGlossEnricher do
  let(:store) { Rails.root.join("tmp/spec-vi-glosses.json") }
  let(:page) { Rails.root.join("tmp/spec-vi-curated-page.json") }

  after do
    store.delete if store.exist?
    page.delete if page.exist?
  end

  def run(lexemes: {}, senses: {}, radicals: {}, curated: [])
    store.write(JSON.generate({"lexemes" => lexemes, "senses" => senses, "radicals" => radicals}))
    described_class.new(path: store, curated: Huayu::CuratedGlosses.new(paths: curated)).call
  end

  it "adds the Vietnamese gloss beside the English and Russian ones" do
    lexeme = create(:lexeme, kind: :word, text: "謝謝", meanings: {"en" => "thank you", "ru" => "спасибо"})

    run(lexemes: {"謝謝" => "cảm ơn"})

    expect(lexeme.reload.meanings).to(eq("en" => "thank you", "ru" => "спасибо", "vi" => "cảm ơn"))
    expect(lexeme.search_text).to(include("cảm ơn"))
  end

  it "fills each sense by its Chinese definition and leaves the others alone" do
    lexeme = create(:lexeme, kind: :character, text: "一", meanings: {"en" => "one"})
    first = LexemeSense.create!(lexeme:, position: 0, gloss_zh: "第一。", meanings: {"en" => "first"})
    second = LexemeSense.create!(lexeme:, position: 1, gloss_zh: "全、滿、整。", meanings: {"en" => "whole"})

    run(lexemes: {"一" => "một"}, senses: {"一" => {"第一。" => "thứ nhất"}})

    expect(first.reload.meanings["vi"]).to(eq("thứ nhất"))
    expect(second.reload.meanings).not_to(have_key("vi"))
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
