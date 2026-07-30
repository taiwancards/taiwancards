# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Regional variants" do
  it "shows the reading differences by default" do
    sign_in(create(:user))

    get(variants_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("垃圾", "ㄌㄜˋ ㄙㄜˋ", "lājī"))
  end

  it "shows the Taiwan and Hong Kong character split" do
    sign_in(create(:user))

    get(variants_path(section: "glyph"))

    expect(response.body).to(include("裡", "裏"))
    expect(response.body).to(include(I18n.t("variants.hongkong")))
  end

  it "shows the four-region word table with the peanut trap" do
    sign_in(create(:user))

    get(variants_path(section: "word"))

    expect(response.body).to(include("計程車", "的士", "德士"))
    expect(response.body).to(include("土豆"))
    expect(response.body).to(include(I18n.t("variants.singapore")))
  end

  it "falls back to the first section when asked for nonsense" do
    sign_in(create(:user))

    get(variants_path(section: "nope"))

    expect(response.body).to(include(I18n.t("variants.intro.reading")))
  end

  it "never claims a reading it could not stand behind" do
    expect(VariantsHelper::READINGS.map(&:first)).not_to(include("液體"))
  end
end
