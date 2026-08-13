# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Medicine and hospitals" do
  def import(entries)
    path = Rails.root.join("tmp/medicine_request_spec.json")
    path.write(entries.to_json)
    Huayu::MedicineImporter.new(path:).call
  ensure
    path.delete if path.exist?
  end

  def entry(text, category, extra = {})
    {"text" => text, "pinyin" => "cè shì", "en" => "gloss #{text}", "ru" => "тест", "category" => category}.merge(
      extra
    )
  end

  it "shows the empty notice when nothing is imported yet" do
    get(medicine_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("medicine.empty")))
  end

  it "renders the diagrams, the category sections and the popover cards" do
    import(
      [
        entry("心臟", "organs", "tier" => 1),
        entry("掛號", "hospital"),
        entry("拉肚子", "symptoms", "formal" => "腹瀉"),
        entry("腹瀉", "symptoms", "folk" => "拉肚子")
      ]
    )

    get(medicine_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("medicine.diagrams.hospital")))
    expect(response.body).to(include(I18n.t("medicine.diagrams.organs")))
    expect(response.body).to(include(I18n.t("medicine.categories.organs")))
    expect(response.body).to(include("data-controller=\"diagram-map\""))
    expect(response.body).to(include("data-diagram-map-cards-value"))
    expect(response.body).to(include("data-station=\"心臟\""))
    expect(response.body).to(include(dict_entry_path(text: "掛號")))
    expect(response.body).to(include(I18n.t("medicine.folk_label")))
  end

  it "renders in Russian with translated categories" do
    import([entry("醫院", "hospital")])

    in_locale(:ru) { get(medicine_path) }

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("medicine.title", locale: :ru)))
    expect(response.body).to(include(I18n.t("medicine.categories.hospital", locale: :ru)))
  end

  it "offers the study menu to signed-in users" do
    import([entry("護理師", "people")])
    sign_in(create(:user))

    get(medicine_path)

    expect(response.body).to(include(I18n.t("everyday.make_deck_button")))
    expect(response.body).to(include(quick_add_path))
  end
end
