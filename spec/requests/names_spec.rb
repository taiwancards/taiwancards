# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Naming section", :no_auth do
  let!(:source) do
    ContentSource.create!(
      slug: Huayu::TaiwanNames::SOURCE_SLUG,
      name: "Name records",
      attribution: "Name data from Wikidata, dedicated to the public domain under CC0 1.0.",
      license_name: "CC0 1.0",
      license_commercial: true,
      register: :official,
      enabled: true,
      enabled_for_admins: true
    )
  end

  it "counts surnames from the record rather than naming any itself" do
    get("/names")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("陳"))
    expect(response.body).to(include(I18n.t("names.shape.compact")))
    expect(response.body).to(include(I18n.t("names.characters.caution")))
  end

  it "narrows the characters by semantic field" do
    get("/names", params: {field: "nature"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("names.fields.nature")))
  end

  it "narrows by the position a character usually takes" do
    get("/names", params: {position: "first"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("names.positions.first")))
  end

  it "says plainly what the pair score means and where the counts come from" do
    get("/names")

    expect(response.body).to(include(I18n.t("names.pairs.heading")))
    expect(response.body).to(include("PMI"))
    expect(response.body).to(include(Huayu::TaiwanNames.source.attribution))
  end

  it "refuses a field nobody publishes rather than showing everything" do
    get("/names", params: {field: "nonsense"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("names.filters.all")))
  end
end

RSpec.describe "Naming by generation", :no_auth do
  it "sorts the characters by how common they are in the generation asked for" do
    get("/names", params: {cohort: "recent"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("names.cohorts.recent")))
    expect(response.body).to(include(I18n.t("names.cohort_note")))
  end

  it "keeps the generations apart rather than showing one list for everyone" do
    recent = Huayu::TaiwanNames.filter(cohort: "recent", limit: 30).map(&:text)
    elder = Huayu::TaiwanNames.filter(cohort: "elder", limit: 30).map(&:text)

    expect(recent).not_to(be_empty)
    expect(elder).not_to(be_empty)
    expect((recent & elder).size).to(be < recent.size)
  end

  it "leaves a character out of a generation that never used it" do
    rows = Huayu::TaiwanNames.filter(cohort: "recent", limit: 500)

    expect(rows).to(all(satisfy { |row| row.per_mille("recent").positive? }))
  end
end

RSpec.describe "Name assistant", :no_auth do
  it "hands the counts over as a file the browser can hold, with no session attached" do
    get("/names/data.json")

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("application/json"))
    expect(response.headers["Set-Cookie"]).to(be_nil)
    expect(response.headers["Cache-Control"]).to(include("public"))

    body = response.parsed_body
    expect(body["characters"]).to(be_present)
    expect(body["surnames"]).to(be_present)
    expect(body["contours"]).to(be_present)
  end

  it "states plainly that what the reader types never reaches us" do
    get("/names")

    expect(response.body).to(include(I18n.t("names.assistant.privacy_title")))
    expect(response.body).to(include("The whole calculation runs in your browser"))
  end

  it "refuses to pass the suggestion off as a verdict" do
    get("/names")

    expect(response.body).to(include(I18n.t("names.assistant.disclaimer")))
  end

  it "carries the gender split the ranking needs" do
    leaning = Huayu::TaiwanNames.characters.count { |row| row.lean.present? }

    expect(leaning).to(be_positive)
    expect(Huayu::TaiwanNames.characters.count { |row| row.strokes.present? }).to(be_positive)
    expect(Huayu::TaiwanNames.meta["male"].to_i).to(be_positive)
    expect(Huayu::TaiwanNames.meta["female"].to_i).to(be_positive)
  end
end
