# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Study sessions" do
  before do
    5.times do |n|
      create(
        :lexeme,
        :character,
        text: [0x4E00 + n].pack("U"),
        readings: {"pinyin" => "yī", "zhuyin" => "ㄧ"},
        meanings: {"en" => "one"},
        data: {"moe_index" => n + 1}
      )
    end
  end

  it "opens a cram session that activates fresh characters" do
    get("/study", params: {mode: "cram", size: 3})
    expect(response).to(have_http_status(:ok))
    expect(LexemeMemory.active.count).to(eq(3 * 4))
    expect(response.body).to(include("name=\"lexeme_id\""))
  end

  it "grades the shown facet on review and advances the queue" do
    get("/study", params: {mode: "cram", size: 3})
    lexeme_input = response.body[/<input[^>]*name="lexeme_id"[^>]*>/]
    lexeme_id = lexeme_input[/value="(\d+)"/, 1]
    facet_input = response.body[/<input[^>]*name="facet"[^>]*>/]
    facet = facet_input[/value="(\w+)"/, 1]
    session_input = response.body[/<input[^>]*name="session_id"[^>]*>/]
    session_id = session_input[/value="([^"]+)"/, 1]

    post(
      "/study/review",
      params: {lexeme_id:, facet:, session_id:, rating: "good", elapsed_ms: 900},
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    )

    expect(response).to(have_http_status(:ok))
    memory = LexemeMemory.find_by(lexeme_id:, facet: LexemeMemory.facets[facet])
    expect(memory.reps).to(eq(1))
    expect(LexemeReview.where(lexeme_id:, facet: LexemeMemory.facets[facet]).count).to(eq(1))
    expect(response.body).to(include("study-progress"))
  end

  it "requeues a missed card within the session without counting it done" do
    get("/study", params: {mode: "cram", size: 2})
    lexeme_id = response.body[/<input[^>]*name="lexeme_id"[^>]*>/][/value="(\d+)"/, 1]
    facet = response.body[/<input[^>]*name="facet"[^>]*>/][/value="(\w+)"/, 1]
    session_id = response.body[/<input[^>]*name="session_id"[^>]*>/][/value="([^"]+)"/, 1]

    post(
      "/study/review",
      params: {lexeme_id:, facet:, session_id:, rating: "again"},
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    )

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("0 / "))
  end
end
