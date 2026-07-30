# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The donation button" do
  let(:script) { "https://cdn.example.test/1.0.0/button.js" }

  def offer(script_url: script, slug: "someone")
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("DONATE_SCRIPT_URL").and_return(script_url))
    allow(ENV).to(receive(:[]).with("DONATE_SLUG").and_return(slug))
  end

  before { offer(script_url: nil, slug: nil) }

  it "stays out of sight until it is configured" do
    get(help_path)

    expect(response.body).not_to(include("bmc-button"))
    expect(response.body).not_to(include(I18n.t("help.donate")))
  end

  it "sits at the foot of the help page once configured" do
    offer
    get(help_path)

    expect(response.body).to(include(script))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("help.donate"))))
    last_section = CGI.escapeHTML(I18n.t("help.sections.profile.body"))
    expect(response.body.index("bmc-button")).to(be > response.body.index(last_section))
  end

  it "asks Turbo for a fresh document, because the widget writes into the page as it parses" do
    offer
    get(help_path)

    expect(response.body[/<meta[^>]*turbo-visit-control[^>]*>/]).to(include("reload"))
  end

  it "never reaches the landing page or any other screen", :no_auth do
    offer

    [root_path, login_path, privacy_path].each do |path|
      get(path)

      expect(response.body).not_to(include("bmc-button"))
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

  it "needs both halves before it appears" do
    offer(slug: nil)
    get(help_path)

    expect(response.body).not_to(include("bmc-button"))
  end
end
