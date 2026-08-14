# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stories" do
  let!(:word) { create(:lexeme, kind: :word, text: "夜市", meanings: {"en" => "night market"}) }

  let!(:text) do
    ReadingText.create!(
      kind: :story,
      title: "逛夜市",
      level_tag: "A2",
      restricted: true,
      source: "stories",
      body: "我們去夜市。\n人很多。",
      body_data: {
        "slug" => "night-market",
        "category" => "everyday",
        "translations" => {
          "en" => ["We're going to the night market.", "There are a lot of people."],
          "ru" => ["Мы идём на ночной рынок.", "Народу много."]
        }
      }
    )
  end

  context("with restricted access") do
    before { sign_in(create(:user, restricted_content: true)) }

    it "lists the texts by category" do
      get("/stories")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("逛夜市"))
      expect(response.body).to(include("/stories/#{text.id}"))
    end

    it "filters the index by category" do
      get("/stories", params: {category: "fable"})

      expect(response).to(have_http_status(:ok))
      expect(response.body).not_to(include("/stories/#{text.id}"))
    end

    it "renders the text as tappable tokens with the translation of each line" do
      get("/stories/#{text.id}")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("data-analyzer-target=\"word\""))
      expect(response.body).to(include("We&#39;re going to the night market."))
    end

    it "shows the Russian translation on the Russian page" do
      get("/ru/stories/#{text.id}")

      expect(response.body).to(include("Мы идём на ночной рынок."))
      expect(response.body).not_to(include("There are a lot of people."))
    end
  end

  it "keeps the section out of the reader and away from everybody else" do
    sign_in(create(:user))

    get("/stories")
    expect(response).to(redirect_to(root_path))

    get("/reader")
    expect(response.body).not_to(include("逛夜市"))
  end
end
