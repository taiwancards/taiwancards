# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signing out" do
  it "ends the session and keeps the member area closed afterwards" do
    delete("/logout")

    expect(response).to(redirect_to(login_path))
    expect(flash[:notice]).to(eq(I18n.t("auth.signed_out")))

    get("/progress/history")
    expect(response).to(redirect_to(login_path))
  end

  it "drops an impersonation along with the admin's own session" do
    sign_in(create(:user, :admin))
    post(admin_impersonate_path(create(:user)))
    get(admin_users_path)
    expect(response).to(redirect_to(root_path))

    delete("/logout")
    get("/auth/google_oauth2/callback")

    get(admin_users_path)
    expect(response).to(have_http_status(:ok))
  end
end
