# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SenseMeaningFiller do
  let(:source) do
    ContentSource.create!(
      slug: "moe_concised",
      license_commercial: true,
      name: "MOE",
      attribution: "MOE.",
      enabled: true,
      enabled_for_admins: true
    )
  end

  def sense_for(text, definitions, meanings: {"en" => "one; single", "ru" => "один"})
    lexeme = create(:lexeme, kind: :word, text:, meanings:)
    definitions.each_with_index do |definition, index|
      lexeme.senses.create!(position: index, gloss_zh: definition, content_source: source)
    end

    lexeme
  end

  it "copies the whole-word meaning onto a lexeme that has exactly one sense" do
    lexeme = sense_for("測試", ["試驗。"])

    described_class.new(io: StringIO.new).call

    expect(lexeme.senses.first.reload.meanings).to(eq({"en" => "one; single", "ru" => "один"}))
  end

  it "leaves a multi-sense lexeme alone, since the flat gloss mixes its senses" do
    lexeme = sense_for("多義", ["第一義。", "第二義。"])

    described_class.new(io: StringIO.new).call

    expect(lexeme.senses.map { |sense| sense.reload.meanings }).to(all(eq({})))
  end

  it "applies our own stored translations, matching by word and Chinese definition" do
    lexeme = sense_for("多義", ["第一義。", "第二義。"])
    store = Rails.root.join("tmp/spec-sense-glosses.jsonl")
    store.write(
      [
        {word: "多義", zh: "第一義。", en: "first sense", ru: "первое значение"},
        {word: "多義", zh: "第二義。", en: "second sense", ru: "второе значение"},
        {word: "多義", zh: "нет такого толкования", en: "stale", ru: "устарело"}
      ].map { |row| JSON.generate(row) }.join("\n")
    )
    stub_const("#{Huayu::SenseGlossStore}::PATH", store)

    result = described_class.new(io: StringIO.new).call

    expect(result[:stored]).to(eq(2))
    expect(lexeme.senses.map { |sense| sense.reload.meaning("ru") }).to(
      eq(["первое значение", "второе значение"])
    )
  ensure
    store&.delete if store&.exist?
  end
end
