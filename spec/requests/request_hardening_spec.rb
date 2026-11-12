# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Request hardening" do
  it "skips a malformed zhuyin result instead of failing the whole submission", :no_auth do
    post("/practice/zhuyin-trainer", params: {results: ["ㄅ", {symbol: "ㄆ", correct: true}]}, as: :json)

    expect(response).to(have_http_status(:ok))
  end

  it "keeps only the drill sounds that exist" do
    user = sign_in(create(:user))

    post(practice_drill_result_path, params: {misses: {"b|ㄅ" => 2, "ㄇㄚˇ" => 1, "junk-key" => 5}}, as: :json)

    expect(user.reload.phonetic_misses).to(eq({"b|ㄅ" => 2, "ㄇㄚˇ" => 1}))
  end

  it "adds the language to an address without taking routing options from the query", :no_auth do
    raw_get("/grammar?script_name=/en/elsewhere")

    expect(response).to(have_http_status(:moved_permanently))
    expect(URI.parse(response.location).path).to(eq("/en/grammar"))
  end

  it "keeps the query of an address it adds the language to", :no_auth do
    raw_get("/grammar?q=%E4%BA%86")

    expect(response.location).to(end_with("/en/grammar?q=%E4%BA%86"))
  end
end
