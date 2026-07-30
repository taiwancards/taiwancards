# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profile panels" do
  it "saves a settings change inline without a redirect" do
    patch("/profile", params: {inline: "1", user: {zhuyin_position: "over"}})

    expect(response).to(have_http_status(:no_content))
    expect(@authenticated_user.reload.zhuyin_position).to(eq("over"))
  end

  it "still redirects when the panel was submitted by its own button" do
    patch("/profile", params: {user: {level: "4"}})

    expect(response).to(redirect_to(profile_path))
    expect(@authenticated_user.reload.level).to(eq("4"))
  end

  it "returns to the tab the form was submitted from" do
    patch("/profile", params: {tab: "level", user: {level: "4"}})

    expect(response).to(redirect_to(profile_level_path))
  end

  it "keeps the email out of the writable params" do
    original = @authenticated_user.email

    patch("/profile", params: {user: {email: "someone-else@example.com"}})

    expect(@authenticated_user.reload.email).to(eq(original))
  end

  it "explains the font recommendation and the Google backup in both locales" do
    %i[en ru].each do |locale|
      expect(I18n.t("auth.font_recommendation", locale:)).to(be_present)
      expect(I18n.t("auth.google_backup_hint", locale:)).to(be_present)
    end
  end

  it "splits the profile into tabs and reaches every one of them" do
    ProfilesHelper::TABS.each do |tab|
      get(ProfilesHelper::TABS.index(tab).zero? ? "/profile" : "/profile/#{tab == "guide" ? "guide" : tab}")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("auth.tabs.#{tab}")))
    end
  end

  it "keeps the account and the security panels on the first tab" do
    get("/profile")

    expect(response.body).to(include(I18n.t("auth.account")))
    expect(response.body).to(include(I18n.t("auth.security")))
    expect(response.body).not_to(include(I18n.t("auth.projection_field")))
  end

  it "wipes learning state as well as reviews when progress is reset" do
    lexeme = create(:lexeme, kind: :character, text: "水", meanings: {"en" => "water"})
    Lexemes::Activator.new.call(lexeme)
    @authenticated_user.update!(
      prefs: {
        "start_level" => "zero",
        "level" => "4",
        "path_steps" => ["zhuyin"],
        "zhuyin_mastery" => {"ㄅ" => {"streak" => 3}},
        "practice_runs" => {"drill" => 2}
      }
    )

    delete("/profile/reset")

    user = @authenticated_user.reload
    expect(user.lexeme_memories.count).to(eq(0))
    expect(user.start_level).to(be_nil)
    expect(user.level).to(eq("zero"))
    expect(user.path_steps_done).to(be_empty)
    expect(user.zhuyin_mastery).to(be_empty)
    expect(user.practice_runs).to(be_empty)
  end

  it "keeps display preferences through a reset" do
    @authenticated_user.update!(prefs: {"zhuyin_position" => "over", "text_direction" => "vertical", "level" => "5"})

    delete("/profile/reset")

    user = @authenticated_user.reload
    expect(user.zhuyin_position).to(eq("over"))
    expect(user.text_direction).to(eq("vertical"))
    expect(user.level).to(eq("zero"))
  end
end
