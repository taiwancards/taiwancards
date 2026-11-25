# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Digital Asset Links", :no_auth do
  let(:upload) { "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99" }
  let(:signing) { "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF" }

  def android_app(package:, fingerprints:)
    allow(ENV).to(receive(:[]).and_call_original)
    allow(ENV).to(receive(:[]).with("ANDROID_PACKAGE_NAME").and_return(package))
    allow(ENV).to(receive(:[]).with("ANDROID_CERT_FINGERPRINTS").and_return(fingerprints))
  end

  def fetch_links = raw_get("/.well-known/assetlinks.json")

  it "is absent while the Android app is not configured" do
    fetch_links

    expect(response).to(have_http_status(:not_found))
    expect(response.headers["Set-Cookie"]).to(be_blank)
  end

  it "delegates the whole site to every signing certificate of the configured package" do
    android_app(package: "app.taiwancards.study", fingerprints: "#{upload}, #{signing}")
    fetch_links

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("application/json"))
    expect(response.headers["cache-control"]).to(include("public"))
    expect(response.headers["Set-Cookie"]).to(be_blank)
    expect(response.body).to(eq(AndroidApp.asset_links.to_json))
    expect(JSON.parse(response.body)).to(
      eq(
        [
          {
            "relation" => ["delegate_permission/common.handle_all_urls"],
            "target" => {
              "namespace" => "android_app",
              "package_name" => "app.taiwancards.study",
              "sha256_cert_fingerprints" => [
                "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99",
                "01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF"
              ]
            }
          }
        ]
      )
    )
  end

  it "stays absent when a fingerprint or the package name is malformed" do
    android_app(package: "app.taiwancards.study", fingerprints: "#{signing},AB:CD")
    fetch_links
    expect(response).to(have_http_status(:not_found))

    android_app(package: "taiwancards", fingerprints: signing)
    fetch_links
    expect(response).to(have_http_status(:not_found))
  end

  it "is served at the bare well-known path, never under a language prefix" do
    android_app(package: "app.taiwancards.study", fingerprints: signing)

    expect(Locales.prefixable?("/.well-known/assetlinks.json")).to(be(false))
    expect { Rails.application.routes.recognize_path("/en/.well-known/assetlinks.json") }
      .to(raise_error(ActionController::RoutingError))
  end
end
