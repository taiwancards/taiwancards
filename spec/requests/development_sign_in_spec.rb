# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Development sign-in", :no_auth do
  before do
    allow(User).to(receive(:signed_in_by_default?).and_return(true))
    User.create!(email: "owner@example.com", password: "password123", prefs: {"goal" => "guided"})
  end

  it "signs the owner in for a request from this machine" do
    get("/profile")

    expect(response).to(have_http_status(:ok))
  end

  it "leaves a request that arrives through a tunnel signed out" do
    get("/profile", headers: {"X-Forwarded-For" => "203.0.113.7"})

    expect(response).to(redirect_to(%r{/login}))
  end
end
