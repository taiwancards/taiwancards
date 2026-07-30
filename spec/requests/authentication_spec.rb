# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication and progress portability" do
  it "redirects an unauthenticated visitor to the login page", :no_auth do
    get("/progress/history")
    expect(response).to(redirect_to("/login"))
  end

  it "signs in through Google and lands in the app", :no_auth do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "sign-in-uid",
      info: {email: "returning@gmail.com", name: "Den"},
      credentials: {token: "t", refresh_token: "r", expires_at: 2.hours.from_now.to_i}
    )

    expect { get("/auth/google_oauth2/callback") }.to(change(User, :count).by(1))

    user = User.find_by(google_uid: "sign-in-uid")
    expect(user.verified?).to(be(true))
  end

  describe "progress export/import" do
    let(:lexeme) { create(:lexeme, kind: :word, text: "學校") }

    it "exports the current user's progress and re-imports it by natural key" do
      memory = Lexemes::Activator.new.activate(lexeme, :recognition)
      Lexemes::ReviewProcessor.new.call(memory, rating: "good")

      get("/profile/export.json")
      expect(response).to(have_http_status(:ok))
      payload = response.parsed_body
      expect(payload["memories"].first).to(include("kind" => "word", "text" => "學校", "facet" => "recognition"))

      other = create(:user)
      result = Progress::Import.new(other).call(payload)
      expect(result[:memories]).to(be_positive)
      restored = other.lexeme_memories.joins(:lexeme).find_by(lexemes: {text: "學校"})
      expect(restored.stability).to(eq(memory.reload.stability))
    end
  end
end
