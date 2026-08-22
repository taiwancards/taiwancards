# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cangjie textbook", :no_auth do
  it "opens the map with a key for every letter" do
    get("/en/cangjie/lessons")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("/en/cangjie/lessons/a", "/en/cangjie/lessons/y", "/en/cangjie/lessons/novice"))
    expect(response.body).to(include(I18n.t("cangjie_lessons.map", locale: :en)))
  end

  it "links the map to the keyboard trainer and back" do
    get("/en/cangjie/lessons")
    expect(response.body).to(include("/en/cangjie\""))

    get("/en/cangjie")
    expect(response.body).to(include("/en/cangjie/lessons"))
  end

  it "shows a letter lesson with its shapes, a worked split and its code" do
    get("/en/cangjie/lessons/a")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("日 — sun"))
    expect(response.body).to(include("amyo"))
    expect(response.body).to(include("/en/characters/#{CGI.escape("是")}"))
  end

  it "carries the drill tasks into the page" do
    get("/en/cangjie/lessons/n")

    expect(response.body).to(include("cangjie-drill"))
    expect(response.body).to(include(I18n.t("cangjie_lessons.drills.title", locale: :en)))
  end

  it "serves the speed trainer with both pools and the progress panel" do
    get("/en/cangjie/lessons")

    expect(response.body).to(include("cangjie-speed", "cangjie-progress"))
    expect(response.body).to(include(I18n.t("cangjie_lessons.speed.title", locale: :en)))
    expect(response.body).to(include(I18n.t("cangjie_lessons.progress.title", locale: :en)))
    expect(response.body).to(include("的"))
  end

  it "marks lesson tiles and character chips for the progress script" do
    get("/en/cangjie/lessons")
    expect(response.body).to(include("data-cangjie-progress-target=\"card\""))

    get("/en/cangjie/lessons/a")
    expect(response.body).to(include("data-cangjie-progress-target=\"chip\""))
    expect(response.body).to(include("data-cangjie-drill-slug-value=\"a\""))
  end

  it "reads the same lesson in Russian" do
    get("/ru/cangjie/lessons/a")

    expect(response.body).to(include("日 — солнце"))
  end

  it "answers 404 for a slug it does not teach" do
    get("/en/cangjie/lessons/nope")

    expect(response).to(have_http_status(:not_found))
  end
end
