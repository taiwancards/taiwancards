# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Shells do
  subject(:shells) { described_class.new.call }

  it "builds one shell per locale, all at the one page width" do
    expect(shells.keys).to(match_array(I18n.available_locales.map(&:to_s)))
    expect(shells.fetch("en").keys).to(eq([described_class::KEY]))
    expect(shells.fetch("en").fetch(described_class::KEY)).to(include(ApplicationHelper::PAGE_WIDTH))
  end

  it "offers no way into an account" do
    shells.each_value do |widths|
      widths.each_value do |html|
        expect(html).not_to(include("/login", "csrf-token", I18n.t("auth.login")))
      end
    end
  end

  it "carries the offline navigation and its own search" do
    html = shells.fetch("en").fetch(described_class::KEY)

    expect(html).to(include("/en/offline/browse", "offline-jump"))
  end

  it "speaks the locale it was asked for" do
    expect(shells.fetch("ru").fetch(described_class::KEY)).to(include("lang=\"ru\""))
  end
end
