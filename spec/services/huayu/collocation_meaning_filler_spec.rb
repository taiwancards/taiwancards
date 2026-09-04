# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CollocationMeaningFiller do
  let(:store) { Rails.root.join("tmp/spec-collocation-glosses.jsonl") }
  let(:curated) { Rails.root.join("tmp/spec-curated-glosses.json") }

  def write_store(rows)
    store.write(rows.map { |row| JSON.generate(row) }.join("\n"))
    stub_const("#{Huayu::CollocationGlossStore}::PATH", store)
  end

  def write_curated(rows)
    curated.write(JSON.generate(rows))
  end

  def run(paths: [])
    described_class.new(io: StringIO.new, curated_paths: paths).call
  end

  after do
    store.delete if store.exist?
    curated.delete if curated.exist?
  end

  it "replaces a gloss the store has since corrected" do
    lexeme = create(
      :lexeme,
      kind: :collocation,
      text: "蠶眠",
      meanings: {"en" => "the dormant moulting stage of a silkworm", "ru" => "спячка шелкопряда"}
    )
    write_store(
      [{text: "蠶眠", en: "the dormant molting stage of a silkworm", ru: "спячка шелкопряда"}]
    )

    expect(run[:filled]).to(eq(1))
    expect(lexeme.reload.meanings["en"]).to(eq("the dormant molting stage of a silkworm"))
  end

  it "fills a gloss that is missing" do
    lexeme = create(:lexeme, kind: :collocation, text: "浮腫", meanings: {})
    write_store([{text: "浮腫", en: "edema", ru: "отёк"}])

    run

    expect(lexeme.reload.meanings).to(eq({"en" => "edema", "ru" => "отёк"}))
  end

  it "leaves a locale that a curated page file owns" do
    lexeme = create(:lexeme, kind: :collocation, text: "貧血", meanings: {"en" => "anemia"})
    write_store([{text: "貧血", en: "anaemia, low blood", ru: "малокровие"}])
    write_curated([{"text" => "貧血", "en" => "anemia"}])

    run(paths: [curated.to_s])

    expect(lexeme.reload.meanings).to(eq({"en" => "anemia", "ru" => "малокровие"}))
  end

  it "reads a curated file keyed by text as well as one that is a list" do
    lexeme = create(:lexeme, kind: :collocation, text: "高速公路", meanings: {"en" => "freeway"})
    write_store([{text: "高速公路", en: "highway", ru: "автомагистраль"}])
    write_curated({"高速公路" => {"en" => "freeway"}})

    run(paths: [curated.to_s])

    expect(lexeme.reload.meanings["en"]).to(eq("freeway"))
  end

  it "reports an empty store without touching anything" do
    lexeme = create(:lexeme, kind: :collocation, text: "空", meanings: {"en" => "empty"})
    store.write("")
    stub_const("#{Huayu::CollocationGlossStore}::PATH", store)

    expect(run[:filled]).to(eq(0))
    expect(lexeme.reload.meanings["en"]).to(eq("empty"))
  end
end
