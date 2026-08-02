# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mobile navigation" do
  it "renders a bottom tab bar with at most four destinations and a header menu link" do
    get("/desk")

    expect(response.body).to(include("data-tour=\"nav\"").or(include("nav")))
    tabs = response.body.scan(%r{<nav[^>]*fixed[^>]*>.*?</nav>}m).first
    expect(tabs).to(be_present)
    expect(tabs.scan(/<a /).size).to(be <= NavHelper::MOBILE_TAB_SLOTS)
    expect(response.body).to(include("href=\"#{menu_path}\""))
  end

  it "keeps the desktop subnav out of the mobile flow" do
    get("/desk")

    expect(response.body).to(match(/<nav[^>]*sticky[^>]*hidden[^>]*md:block/))
  end

  it "lists every section on the More screen" do
    get("/menu")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(dict_path, characters_path, reader_path, placement_path))
    expect(response.body).to(include(profile_path, help_path))
  end
end
