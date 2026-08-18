# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Syllable chart", :no_auth do
  it "opens without an account and lays every syllable out by its initial" do
    get("/syllables")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("ㄅㄚ"))
    expect(response.body).to(include("zhang"))
  end

  it "offers both studio voices and hands the player a template rather than every address" do
    get("/syllables")

    expect(response.body).to(include(I18n.t("syllables.voices.female")))
    expect(response.body).to(include(I18n.t("syllables.voices.male")))
    expect(response.body).to(include("%s"))
    expect(response.body.scan(/data-key=/).size).to(be > 1_000)
  end

  it "credits the corpus the recordings come from" do
    get("/syllables")

    expect(response.body).to(include(Huayu::CnsVoice::ATTRIBUTION))
  end

  it "lets the shared cache hold the page and asks no session of the reader" do
    get("/syllables")

    expect(response.headers["Cache-Control"]).to(include("public"))
    expect(response.headers["Vary"]).to(eq("Accept-Encoding"))
    expect(response.headers["Set-Cookie"]).to(be_nil)
  end
end

RSpec.describe "Character audio", :no_auth do
  it "falls back to the syllable corpus so a reading is never left silent" do
    lexeme = create(
      :lexeme,
      kind: :character,
      text: "囧",
      readings: {"zhuyin" => "ㄐㄩㄥˇ", "pinyin" => "jiǒng"},
      meanings: {"en" => "embarrassed"}
    )

    get("/characters/#{ERB::Util.url_encode(lexeme.text)}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("jiong3"))
  end
end
