# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Desks" do
  before { Rails.application.load_seed }

  it "sends a returning person straight to their language desk" do
    user = create(:user, google_uid: "desk-uid")
    sign_in(user)

    expect(response).to(redirect_to("/desk"))
  end

  it "renders the Taiwanese home screen" do
    get("/desk")

    expect(response).to(have_http_status(:ok))
  end

  it "renders in the language stored on the user" do
    sign_in(create(:user, locale: "ru"))

    get("/desk")
    expect(response.body).to(include("В колоде"))
  end
end
