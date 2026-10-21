# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Confusable words" do
  let(:pair) { Huayu::WordPairs.find("hui-neng-keyi") }

  it "lists the sets by level for a guest and lets the edge cache them", :no_auth do
    get("/ru/pairs")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(pair.title))
    expect(response.body).to(include("id=\"a1\""))
    expect(response.headers["Cache-Control"]).to(include("public"))
  end

  it "shows the rule, the uses, the mistakes and the exercises of a set", :no_auth do
    get("/en/pairs/#{pair.slug}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(ERB::Util.html_escape(pair.rule(:en))))
    expect(response.body).to(include(pair.mistakes.first.right))
    expect(response.body).to(include("data-controller=\"course-quiz\""))
    expect(response.body).not_to(include("<form"))
  end

  it "answers 404 for a set that does not exist", :no_auth do
    get("/en/pairs/nothing-here")

    expect(response).to(have_http_status(:not_found))
  end
end
