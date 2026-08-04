# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin impersonation" do
  let(:admin) { create(:user, admin: true, locale: "en") }
  let(:member) {
    create(:user, locale: "ru", prefs: {"mobile_tabs" => %w[deck words]})
  }

  it "shows the app exactly as the member sees it" do
    sign_in(admin)

    post(admin_impersonate_path(member))
    expect(response).to(redirect_to("/ru"))

    in_locale(:ru) { get("/desk") }
    expect(response.body).to(include(I18n.t("nav.help", locale: :ru)))
    expect(response.body).to(include("/ru/dict"))
    expect(response.body).to(include(I18n.t("admin.impersonation_stop", locale: :ru)))
  end

  it "keeps the admin session underneath and can be stopped" do
    sign_in(admin)
    post(admin_impersonate_path(member))

    delete(admin_stop_impersonating_path)

    expect(response).to(redirect_to(admin_users_path))
    get(admin_users_path)
    expect(response).to(have_http_status(:ok))
  end

  it "applies the member's own permissions while impersonating" do
    sign_in(admin)
    post(admin_impersonate_path(member))

    get(admin_users_path)

    expect(response).to(redirect_to(root_path))
  end

  it "refuses to impersonate yourself" do
    sign_in(admin)

    post(admin_impersonate_path(admin))

    expect(response).to(redirect_to(admin_users_path))
    expect(flash[:alert]).to(eq(I18n.t("admin.impersonate_self")))
  end

  it "is closed to non-admins" do
    sign_in(create(:user))

    post(admin_impersonate_path(member))

    expect(response).to(redirect_to(root_path))
    get("/desk")
    expect(response.body).not_to(include(I18n.t("admin.impersonation_stop")))
  end
end
