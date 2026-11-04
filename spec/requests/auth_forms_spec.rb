# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth forms", :no_auth do
  def nested_forms?(html)
    depth = 0
    html.scan(/<\/?form\b/) do |tag|
      depth += tag.start_with?("</") ? -1 : 1
      return true if depth > 1
    end

    false
  end

  it "keeps the Google button out of the login form" do
    get("/login")

    expect(response.body).to(include("/auth/google_oauth2"))
    expect(nested_forms?(response.body)).to(be(false))
  end

  it "offers the other interface languages next to the Google button, on an unhidden row" do
    get("/vi/login")

    expect(response.body).to(
      include(
        I18n.t("language_offer.invite", locale: :en),
        I18n.t("language_offer.invite", locale: :ru),
        "href=\"/ru/login\""
      )
    )
    expect(response.body).not_to(include("data-controller=\"language-offer\""))
  end

  it "keeps the Google button out of the signup form" do
    get("/signup")

    expect(response.body).to(include("/auth/google_oauth2"))
    expect(nested_forms?(response.body)).to(be(false))
  end

  def text_of(html)
    html.gsub(/<[^>]+>/, "").gsub(/\s+/, " ")
  end
end
