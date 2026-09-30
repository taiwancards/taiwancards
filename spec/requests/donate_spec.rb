# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The donation button" do
  def offer(slug: "someone")
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("DONATE_SLUG").and_return(slug))
  end

  before { offer(slug: nil) }

  it "stays out of sight until it is configured" do
    get(support_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include("buymeacoffee"))

    get(root_path)

    expect(response.body).not_to(include(support_path))
  end

  it "has a page of its own, reached from the footer" do
    offer
    get(progress_path)

    expect(response.body).to(include("href=\"#{support_path}\""))
    expect(response.body).not_to(include("buymeacoffee"))

    get(support_path)

    expect(response.body).to(include("https://buymeacoffee.com/someone", CGI.escapeHTML(I18n.t("support.button"))))
  end

  it "is a plain link, so no outside script has to be let through the policy" do
    offer
    get(support_path)

    expect(response.body).not_to(include("bmc-button"))
    expect(response.headers["Content-Security-Policy"].to_s).not_to(include("buymeacoffee"))
  end

  it "opens in its own tab without handing the other site a referrer" do
    offer
    get(support_path)

    button = response.body[/<a[^>]*buymeacoffee[^>]*>/]

    expect(button).to(include("rel=\"noopener\"", "target=\"_blank\""))
  end

  it "is open to guests and never sits on the landing page or the licenses", :no_auth do
    offer

    get(support_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("buymeacoffee"))

    [root_path, login_path, licenses_path].each do |path|
      get(path)

      expect(response.body).not_to(include("buymeacoffee"))
    end
  end
end
