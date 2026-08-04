# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The donation button" do
  def offer(slug: "someone")
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("DONATE_SLUG").and_return(slug))
  end

  before { offer(slug: nil) }

  it "stays out of sight until it is configured" do
    get(licenses_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("buymeacoffee"))
  end

  it "sits with the licences, where the project already explains itself" do
    offer
    get(licenses_path)

    expect(response.body).to(include("https://www.buymeacoffee.com/someone"))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("licenses.donate_button"))))
    expect(response.body.index("buymeacoffee")).to(be > response.body.index(CGI.escapeHTML(I18n.t("licenses.outro"))))
  end

  it "is a plain link, so no outside script has to be let through the policy" do
    offer
    get(licenses_path)

    expect(response.body).not_to(include("bmc-button"))
    expect(response.headers["Content-Security-Policy"].to_s).not_to(include("buymeacoffee"))
  end

  it "opens in its own tab without handing the other site a referrer" do
    offer
    get(licenses_path)

    button = response.body[/<a[^>]*buymeacoffee[^>]*>/]

    expect(button).to(include("rel=\"noopener\""))
    expect(button).to(include("target=\"_blank\""))
  end

  it "never reaches the landing page or any other screen", :no_auth do
    offer

    [root_path, login_path, privacy_path].each do |path|
      get(path)

      expect(response.body).not_to(include("buymeacoffee"))
    end
  end

  it "says in the privacy policy that the button talks to someone else", :no_auth do
    offer
    get(privacy_path)

    expect(response.body).to(include("Buy Me a Coffee"))
  end

  it "keeps the privacy policy silent about it when the button is not offered", :no_auth do
    get(privacy_path)

    expect(response.body).not_to(include("Buy Me a Coffee"))
  end
end
