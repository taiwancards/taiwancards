# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Shells do
  subject(:shells) { described_class.new.call }

  it "builds one shell per locale and page width" do
    expect(shells.keys).to(match_array(I18n.available_locales.map(&:to_s)))
    expect(shells.fetch("en").keys).to(match_array(ApplicationHelper::PAGE_WIDTHS.keys))
  end

  it "offers no way into an account" do
    shells.each_value do |widths|
      widths.each_value do |html|
        expect(html).not_to(include("/login", "csrf-token", I18n.t("auth.login")))
      end
    end
  end

  it "carries the offline navigation and its own search" do
    html = shells.fetch("en").fetch("narrow")

    expect(html).to(include("/en/offline/browse", "offline-jump"))
  end

  it "speaks the locale it was asked for" do
    expect(shells.fetch("ru").fetch("narrow")).to(include("lang=\"ru\""))
  end
end
