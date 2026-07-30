# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Writing trainer" do
  before do
    allow(Huayu::StrokeData).to(receive(:has?).and_return(true))
  end

  it "offers a character to write" do
    create(:lexeme, kind: :character, text: "學", readings: {"pinyin" => "xué", "zhuyin" => "ㄒㄩㄝˊ"})

    get("/writing")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-controller=\"writing-quiz\""))
  end

  it "says so when nothing in the queue can be written" do
    allow(Huayu::StrokeData).to(receive(:has?).and_return(false))
    create(:lexeme, kind: :character, text: "學")

    get("/writing")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("writing.empty")))
  end

  it "builds the queue without one query per candidate" do
    30.times { |index| create(:lexeme, kind: :character, text: (0x4E00 + index).chr(Encoding::UTF_8)) }

    report = count_queries { get("/writing") }

    expect(response).to(have_http_status(:ok))
    expect(report).to(repeat_no_query_more_than(2))
  end

  it "records a grade against the writing facet" do
    lexeme = create(:lexeme, kind: :character, text: "學")

    post("/writing/grade", params: {lexeme_id: lexeme.id, rating: "good"})

    expect(response).to(have_http_status(:ok))
    expect(LexemeMemory.find_by(lexeme:, facet: :writing)).to(be_present)
  end

  it "refuses a rating it does not know" do
    lexeme = create(:lexeme, kind: :character, text: "學")

    post("/writing/grade", params: {lexeme_id: lexeme.id, rating: "brilliant"})

    expect(response).to(have_http_status(:unprocessable_content))
  end

  it "404s for a lexeme that is not writable material" do
    radical = create(:lexeme, kind: :radical, text: "子")

    post("/writing/grade", params: {lexeme_id: radical.id, rating: "good"})

    expect(response).to(have_http_status(:not_found))
  end
end
