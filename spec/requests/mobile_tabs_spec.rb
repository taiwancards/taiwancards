# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customisable bottom tabs" do
  def bottom_nav
    response.body[%r{<nav[^>]*fixed[^>]*>.*?</nav>}m]
  end

  it "falls back to sensible defaults when the user has not chosen" do
    sign_in(create(:user))

    get("/desk")

    expect(bottom_nav).to(include(desk_path, desks_path, pronunciation_path))
    expect(bottom_nav.scan(/<a /).size).to(eq(NavHelper::MOBILE_TAB_SLOTS))
    expect(response.body).to(include("href=\"#{menu_path}\""))
  end

  it "honors the tabs the user picked" do
    tabs = [desk_path, dict_path, writing_path, progress_path]
    sign_in(create(:user, prefs: {"mobile_tabs" => tabs}))

    get("/desk")

    expect(bottom_nav).to(include(dict_path, writing_path, progress_path))
    expect(bottom_nav).not_to(include(pronunciation_path))
  end

  it "takes a destination from any menu group, not a shortlist" do
    tabs = [metro_path, chengyu_path, cangjie_path, calendar_path]
    sign_in(create(:user, prefs: {"mobile_tabs" => tabs}))

    get("/desk")

    tabs.each { |path| expect(bottom_nav).to(include(path)) }
  end

  it "drops a destination that no longer exists in the menu" do
    sign_in(create(:user, prefs: {"mobile_tabs" => %w[/gone-for-good]}))

    get("/desk")

    expect(bottom_nav).to(include(desk_path))
    expect(bottom_nav.scan(/<a /).size).to(eq(NavHelper::MOBILE_TAB_SLOTS))
  end

  it "never shows more than the available slots" do
    tabs = [desk_path, roadmap_path, dict_path, characters_path, reader_path, writing_path]
    sign_in(create(:user, prefs: {"mobile_tabs" => tabs}))

    get("/desk")

    expect(bottom_nav.scan(/<a /).size).to(eq(NavHelper::MOBILE_TAB_SLOTS))
  end

  it "saves the choice from the profile, capped at the slot count" do
    user = sign_in(create(:user))
    tabs = [desk_path, roadmap_path, dict_path, characters_path, reader_path]

    patch("/profile", params: {tab: "display", user: {mobile_tabs: tabs}})

    expect(user.reload.mobile_tabs).to(eq(tabs.first(NavHelper::MOBILE_TAB_SLOTS)))
  end

  it "offers every menu destination on the display tab" do
    sign_in(create(:user))

    get("/profile/display")

    expect(response.body).to(include(I18n.t("auth.mobile_tabs")))
    expect(response.body).to(include("value=\"#{metro_path}\""))
    expect(response.body).to(include("value=\"#{cangjie_path}\""))
  end
end
