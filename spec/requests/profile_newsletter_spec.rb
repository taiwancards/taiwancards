# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Newsletter switch in the profile" do
  it "turns the news off and back on" do
    patch(profile_path, params: {user: {newsletter: "0"}})
    expect(current_user.reload.newsletter?).to(be(false))

    patch(profile_path, params: {user: {newsletter: "1"}})
    expect(current_user.reload.newsletter?).to(be(true))
  end

  it "shows the switch with its promise" do
    get(profile_path)

    expect(response.body).to(include(I18n.t("newsletters.profile.label"), I18n.t("newsletters.profile.hint")))
  end
end
