# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages" do
  it "renders the help page with subsystem links" do
    get("/help")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("丹丹"))
    expect(response.body).to(include(pronunciation_path, tocfl_levels_path))
  end

  it "renders the footer with the developer link and a licenses link" do
    get("/help")
    expect(response.body).to(include("https://github.com/denpatin"))
    expect(response.body).to(include(licenses_path))
  end

  it "dates the footer from the launch year to the current one" do
    get("/help")

    expect(response.body).to(include("#{ApplicationHelper::LAUNCH_YEAR}–#{Time.current.year}"))
  end

  it "shows a single year while the launch year is still running" do
    travel_to(Time.zone.local(ApplicationHelper::LAUNCH_YEAR, 6, 1)) do
      get("/help")

      expect(response.body).to(include(ApplicationHelper::LAUNCH_YEAR.to_s))
    end
  end

  it "renders the licenses page with open-source attribution" do
    get("/licenses")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("CC-CEDICT", "Make Me a Hanzi"))
    expect(response.body).to(include("NAER"))
  end

  it "renders a public privacy policy page", :no_auth do
    get("/privacy")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Privacy Policy"))
    expect(response.body).to(include(I18n.t("privacy_google.heading")))
    expect(response.body).to(include("drive.file"))
    expect(response.body).to(include("support@taiwancards.app"))
  end

  it "renders a public terms of service page", :no_auth do
    get("/terms")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Terms of Service"))
    expect(response.body).to(include("Acceptable use"))
    expect(response.body).to(include("support@taiwancards.app"))
  end

  it "credits the MOE audio in the exact wording the license requires", :no_auth do
    get(licenses_path)

    expect(response.body).to(include(CGI.escapeHTML(Huayu::MoeAudio::ATTRIBUTION)))
    expect(response.body).to(include(Huayu::MoeAudio::SOURCE_URL))
    expect(response.body).to(include("CC BY-ND 3.0 TW"))
    expect(response.body).to(include("creativecommons.org/licenses/by-nd/3.0/tw"))
  end

  it "states the audio version and that files are served unmodified", :no_auth do
    get(licenses_path)

    expect(response.body).to(include("20260626"))
    %i[en ru].each { |locale| expect(I18n.t("licenses.items.moe_audio", locale:)).to(be_present) }
  end

  it "names every Google permission the app actually asks for", :no_auth do
    base = File.read(Rails.root.join("config/initializers/omniauth.rb"))[/scope: "([^"]+)"/, 1]
    requested = [base, User::DRIVE_CONSENT_SCOPE]
      .flat_map { |scope| scope.split(",") }
      .map { |scope| scope.split("/").last }
      .uniq

    get("/privacy")

    expect(requested).to(include("drive.file"))
    requested.each { |scope| expect(response.body).to(include(scope)) }
  end
end
