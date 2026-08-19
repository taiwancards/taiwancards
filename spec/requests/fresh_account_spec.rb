# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Coming back after the account was deleted" do
  def google_as(email, uid)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {email: email, name: "Returner"},
      credentials: {token: "t", refresh_token: "r", expires_at: 2.hours.from_now.to_i}
    )
    get("/auth/google_oauth2/callback")
  end

  it "drops the cookies of the account that is gone before anything else happens", :no_auth do
    victim = sign_in(create(:user, google_uid: "returner", google_email: "returner@example.com"))
    cookies[ZhuyinHelper::HANZI_FONT_COOKIE] = "kai"
    cookies[ZhuyinHelper::READINGS_COOKIE] = "off"
    cookies[:locale] = "ru"
    victim.destroy!

    get("/en/desk")

    expect(cookies[:user_id]).to(be_blank)
    expect(cookies[ZhuyinHelper::HANZI_FONT_COOKIE]).to(be_blank)
    expect(cookies[ZhuyinHelper::READINGS_COOKIE]).to(be_blank)
    expect(cookies[:locale]).to(be_blank)
  end

  it "treats the second registration as a first one", :no_auth do
    victim = create(:user, google_uid: "returner", google_email: "returner@example.com")
    victim.destroy!

    google_as("returner@example.com", "returner")

    fresh = User.find_by(google_uid: "returner")
    expect(fresh).to(be_present)
    expect(fresh.id).not_to(eq(victim.id))
    expect(flash[:notice]).to(eq(I18n.t("auth.signed_up")))
    expect(response).to(redirect_to(onboarding_start_path))
  end

  it "starts that account with an empty history, not a finished tour", :no_auth do
    create(:user, google_uid: "returner", google_email: "returner@example.com").destroy!

    google_as("returner@example.com", "returner")
    fresh = User.find_by(google_uid: "returner")

    expect(fresh.prefs.keys.grep(/intro|path_steps|practice_runs/)).to(be_empty)
    expect(fresh.intro).to(be_pending)
    expect(fresh.intro).not_to(be_required)
    expect(fresh.lexeme_memories).to(be_empty)
  end

  it "asks the browser to forget what it kept outside the cookies", :no_auth do
    create(:user, google_uid: "returner", google_email: "returner@example.com").destroy!

    google_as("returner@example.com", "returner")
    follow_redirect!

    expect(response.body).to(include("data-controller=\"local-reset\""))
  end

  it "leaves a returning account that was never deleted alone", :no_auth do
    create(:user, google_uid: "steady", google_email: "steady@example.com")

    google_as("steady@example.com", "steady")
    follow_redirect!

    expect(response.body).not_to(include("data-controller=\"local-reset\""))
  end

  it "clears every key the app writes, with none left behind" do
    written = Rails
      .root
      .glob("app/javascript/**/*.js")
      .flat_map { |file| file.read.scan(/localStorage\.setItem\(\s*([A-Z_]+|"[^"]+")/) }
      .flatten
      .uniq

    constants = Rails
      .root
      .glob("app/javascript/**/*.js")
      .flat_map { |file| file.read.scan(/const\s+([A-Z_]+)\s*=\s*"([^"]+)"/) }
      .to_h

    keys = written.map { |token| token.start_with?("\"") ? token.delete("\"") : constants[token] }.compact
    cleared = Rails.root.join("app/javascript/controllers/local_reset_controller.js").read

    keys.each { |key| expect(cleared).to(include("\"#{key}\""), "#{key} survives a fresh registration") }
  end
end
