# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Choosing a language on first entry" do
  let(:newcomer) { create(:user, :new_arrival, locale: "vi") }

  before { sign_in(newcomer) }

  it "asks before anything else, in every language, with the likely one first" do
    get("/vi/desk")

    expect(response.body).to(include(I18n.t("language_step.heading", locale: :vi)))
    expect(response.body).not_to(include(I18n.t("onboarding.goal_hint", locale: :vi)))
    %i[en ru vi].each do |locale|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("language_step.edition", locale:))))
    end

    order = %i[vi en ru].map { |locale|
      response.body.index(CGI.escapeHTML(I18n.t("language_step.edition", locale:)))
    }
    expect(order).to(eq(order.sort))
  end

  it "counts confirming the suggested language as a choice, and goes on to the goal" do
    post("/locale/vi", headers: {"HTTP_REFERER" => "http://www.example.com/vi/desk"})
    expect(newcomer.reload).to(have_attributes(locale: "vi", language_chosen?: true))

    get("/vi/desk")
    expect(response.body).not_to(include(I18n.t("language_step.heading", locale: :vi)))
    expect(response.body).to(include(I18n.t("onboarding.goal_hint", locale: :vi)))
  end

  it "moves the interface to another language in the same step" do
    post("/locale/ru", headers: {"HTTP_REFERER" => "http://www.example.com/vi/desk"})

    expect(response).to(redirect_to("http://www.example.com/ru/desk"))
    expect(newcomer.reload).to(have_attributes(locale: "ru", language_chosen?: true))
  end

  it "asks on the start page too" do
    get("/vi/start")

    expect(response.body).to(include(I18n.t("language_step.heading", locale: :vi)))
  end

  it "keeps out of the way of someone who already has a goal" do
    newcomer.update!(goal: "guided")

    get("/vi/desk")
    expect(response.body).not_to(include(I18n.t("language_step.heading", locale: :vi)))
  end
end
