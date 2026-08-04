# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The note about Palladius" do
  before { sign_in(create(:user, locale: "ru")) }

  it "says its piece once on a page, not once per table" do
    PracticeController::PHONETICS_PARTS.each do |part|
      get("/ru/practice/zhuyin", params: {part: part})

      expect(response.body.scan(I18n.t("practice.palladius_note", locale: :ru)).size).to(be <= 1, part)
    end
  end

  it "puts it before the tables rather than after them" do
    get("/ru/practice/zhuyin", params: {part: "initials"})
    note = response.body.index(I18n.t("practice.palladius_note", locale: :ru))
    table = response.body.index("<table")

    expect(note).to(be_present)
    expect(note).to(be < table)
  end

  it "stays out of the way for a reader who does not read Russian" do
    sign_in(create(:user, locale: "en"))

    get("/en/practice/zhuyin", params: {part: "initials"})

    expect(response.body).not_to(include(I18n.t("practice.palladius_note", locale: :ru)))
  end
end
