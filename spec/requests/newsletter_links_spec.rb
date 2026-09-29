# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Links in a newsletter", :no_auth do
  let(:reader) { create(:user, google_uid: "g-1", locale: "ru") }
  let(:newsletter) { Newsletter.create!(subject_ru: "Новости", body_ru: "<div>x</div>") }
  let(:delivery) { NewsletterDelivery.create!(newsletter:, user: reader, locale: "ru", sent_at: Time.current) }

  it "counts a click and lands the reader in the app" do
    token = Newsletters::Tracking.token(delivery, "http://www.example.com/ru/pronunciation")

    2.times { raw_get("/n/#{token}") }

    expect(response).to(redirect_to("http://www.example.com/ru/pronunciation"))
    expect(delivery.reload).to(have_attributes(clicks_count: 2, clicked_at: be_present))
  end

  it "never redirects anywhere else, even with a valid signature" do
    token = Newsletters::Tracking.token(delivery, "https://evil.test/")

    raw_get("/n/#{token}")

    expect(response).to(redirect_to(root_path))
    expect(delivery.reload.clicks_count).to(eq(0))
  end

  it "opens the unsubscribe page in an old browser too" do
    token = delivery.signed_id(purpose: :unsubscribe)

    raw_get(
      "/unsubscribe/#{token}",
      headers: {
        "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
      }
    )

    expect(response).to(have_http_status(:ok))
  end

  it "unsubscribes on the one-click POST mail clients send, without a session or a token" do
    token = delivery.signed_id(purpose: :unsubscribe)

    post("/unsubscribe/#{token}", params: {"List-Unsubscribe" => "One-Click"})

    expect(response).to(have_http_status(:ok))
    expect(reader.reload.newsletter?).to(be(false))
    expect(delivery.reload.unsubscribed_at).to(be_present)
  end

  it "shows a page that unsubscribes by itself but changes nothing on a plain GET" do
    token = delivery.signed_id(purpose: :unsubscribe)

    raw_get("/unsubscribe/#{token}?locale=ru")

    expect(response.body).to(include("auto-submit", I18n.t("newsletters.unsubscribe.button", locale: :ru)))
    expect(reader.reload.newsletter?).to(be(true))
  end

  it "says so when the link is broken" do
    raw_get("/unsubscribe/broken")

    expect(response).to(have_http_status(:not_found))
  end
end
