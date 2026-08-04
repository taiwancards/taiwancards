# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Guest access", :no_auth do
  OPEN_PAGES = %w[
    /characters
    /dict
    /sentences
    /chengyu
    /liangci
    /radicals
    /tocfl
    /tbcl
    /hanzi
    /variants
    /tones
    /practice/zhuyin
    /everyday
    /phrases
    /calendar
    /metro
    /menu
  ]
    .freeze

  GATED_PAGES = %w[
    /desk
    /study
    /desks
    /triage
    /placement
    /practice
    /practice/drill
    /practice/typing
    /pronunciation
    /writing
    /reader
    /progress
    /progress/history
    /profile
    /help
    /tones/drill
  ]
    .freeze

  it "opens every reference section without an account" do
    OPEN_PAGES.each do |path|
      get(path)
      expect(response).to(have_http_status(:ok), "expected #{path} to be open, got #{response.status}")
    end
  end

  it "opens the search" do
    create(
      :lexeme,
      kind: :word,
      text: "水果",
      readings: {"pinyin" => "shuǐguǒ", "zhuyin" => "ㄕㄨㄟˇ ㄍㄨㄛˇ"}
    )

    get("/search", params: {q: "水果"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("水果"))
  end

  it "keeps study, practice and settings behind the login" do
    GATED_PAGES.each do |path|
      get(path)
      expect(response).to(redirect_to(login_path), "expected #{path} to require login")
    end
  end

  it "shows no deck or study controls to a guest" do
    entry = create(:lexeme, kind: :word, text: "水果")

    get(dict_entry_path(text: entry.text))

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("quick_add"))
    expect(response.body).not_to(include(I18n.t("words.add_study")))
    expect(response.body).not_to(include(new_desk_path))
  end

  it "offers the login button and hides study navigation" do
    get("/dict")

    expect(response.body).to(include(login_path))
    expect(response.body).not_to(include(I18n.t("nav.group_learn")))
    expect(response.body).not_to(include(I18n.t("nav.group_settings")))
    expect(response.body).to(include(I18n.t("nav.group_practice")))
  end

  it "explains on the login page that an account only unlocks more" do
    get(login_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("auth.login_pitch"))))
  end
end
