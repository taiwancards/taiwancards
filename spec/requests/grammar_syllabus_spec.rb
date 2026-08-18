# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Grammar syllabus provenance", :no_auth do
  let!(:source) do
    ContentSource.create!(
      slug: Huayu::TbclGrammar::SOURCE_SLUG,
      name: "TBCL benchmarks",
      attribution: "資料來源：國家教育研究院《臺灣華語文能力基準》。",
      license_name: "NAER open data",
      license_commercial: true,
      register: :academic,
      enabled: true,
      enabled_for_admins: true
    )
  end

  it "places a taught point in the official benchmarks and names where that claim comes from" do
    lesson = Huayu::GrammarLessons.taught.find { |candidate| !candidate.supplementary? }
    point = Huayu::TbclGrammar.find(lesson.id)

    get("/grammar/#{lesson.slug}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("grammar.syllabus.official")))
    expect(response.body).to(include(point.tier))
    expect(response.body).to(include(Huayu::TbclGrammar.source.attribution))
  end

  it "says plainly when a point is ours rather than the syllabus's" do
    lesson = Huayu::GrammarLessons.taught.find(&:supplementary?)

    get("/grammar/#{lesson.slug}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("grammar.syllabus.beyond")))
  end

  it "agrees with the published benchmarks on every point it claims to share" do
    mismatched = Huayu::GrammarLessons.taught.reject(&:supplementary?).reject do |lesson|
      point = Huayu::TbclGrammar.find(lesson.id)
      point && point.pattern == lesson.pattern && point.level == lesson.level
    end

    expect(mismatched).to(be_empty)
  end
end
