# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::RuEnricher do
  let(:glosses) { Rails.root.join("tmp/spec-ru-glosses.json") }
  let(:page) { Rails.root.join("tmp/spec-curated-page.json") }

  after do
    glosses.delete if glosses.exist?
    page.delete if page.exist?
  end

  def run(rows, curated: [])
    glosses.write(JSON.generate(rows))
    described_class.new(path: glosses, curated: Huayu::CuratedGlosses.new(paths: curated)).call
  end

  it "replaces a Russian gloss the dictionary has since improved" do
    lexeme = create(:lexeme, kind: :word, text: "測試", meanings: {"ru" => "старое"})

    expect(run({"測試" => "новое"})[:replaced]).to(eq(1))
    expect(lexeme.reload.meanings["ru"]).to(eq("новое"))
  end

  it "leaves a word whose Russian a curated page owns" do
    lexeme = create(
      :lexeme,
      kind: :word,
      text: "看病",
      meanings: {"ru" => "пойти к врачу; принимать больных"}
    )
    page.write(
      JSON.generate([{"text" => "看病", "ru" => "пойти к врачу; принимать больных"}])
    )

    run({"看病" => "обращаться к врачу"}, curated: [page.to_s])

    expect(lexeme.reload.meanings["ru"]).to(eq("пойти к врачу; принимать больных"))
  end

  it "still enriches the character of the same name, which no page owns" do
    character = create(:lexeme, kind: :character, text: "台", meanings: {"ru" => "старое"})
    page.write(JSON.generate([{"text" => "台", "ru" => "тай — единица счёта"}]))

    run({"台" => "помост, сцена"}, curated: [page.to_s])

    expect(character.reload.meanings["ru"]).to(eq("помост, сцена"))
  end
end
