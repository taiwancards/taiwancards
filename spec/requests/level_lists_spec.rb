# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Level word lists", :no_auth do
  let(:source) do
    ContentSource.create!(
      slug: "reference_dictionary",
      name: "Reference dictionary",
      license_name: "CC BY-ND 3.0 TW",
      license_url: "https://creativecommons.org/licenses/by-nd/3.0/tw/",
      attribution: "Ministry of Education, Taiwan",
      license_commercial: true,
      statistics_only: false,
      register: :academic,
      enabled: true,
      enabled_for_admins: true
    )
  end

  def graded_word!
    lexeme = create(
      :lexeme,
      kind: :word,
      text: "醫院",
      readings: {"zhuyin" => "ㄧ ㄩㄢˋ", "pinyin" => "yīyuàn"},
      meanings: {"en" => "hospital", "ru" => "больница"},
      data: {"tbcl_grade" => 2, "tbcl_level" => 2, "tbcl_band" => 1}
    )
    lexeme.senses.create!(position: 0, content_source: source, meanings: {"en" => "hospital"})
    lexeme
  end

  it "hands a grade over as a spreadsheet anybody can open" do
    graded_word!

    get("/tbcl/2.csv")

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("text/csv"))
    expect(response.body).to(include("醫院"))
    expect(response.body).to(include("hospital"))
  end

  it "names every licence the file was built from, so the download can be reused honestly" do
    graded_word!

    get("/tbcl/2.csv")

    expect(response.body).to(include("CC BY-ND 3.0 TW"))
    expect(response.body).to(include("Ministry of Education, Taiwan"))
  end

  it "lets the shared cache hold the file and asks no session of the reader" do
    get("/tbcl/2.csv")

    expect(response.headers["Cache-Control"]).to(include("public"))
    expect(response.headers["Vary"]).to(eq("Accept-Encoding"))
    expect(response.headers["Set-Cookie"]).to(be_nil)
  end
end
