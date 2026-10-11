# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signing out on a development machine", :no_auth do
  let!(:owner) { create(:user, email: "owner@example.com") }

  before do
    allow(User).to(receive(:signed_in_by_default?).and_return(true))
    allow(User).to(receive(:default_owner).and_return(owner))
  end

  it "stays a guest after signing out until someone signs in" do
    get("/en/profile")
    expect(response).to(have_http_status(:ok))

    delete("/en/logout")
    get("/en/profile")
    expect(response).to(redirect_to("/en/login"))
  end
end
