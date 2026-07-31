# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Studying a desk with all facets" do
  let!(:word) do
    create(
      :lexeme,
      kind: :word,
      text: "學校",
      readings: {"pinyin" => "xuéxiào", "zhuyin" => "ㄒㄩㄝˊ ㄒㄧㄠˋ"},
      meanings: {"en" => "school", "ru" => "школа"}
    )
  end

  def desk_with(facets)
    desk = Collection.create!(
      kind: :manual,
      name: "All facets",
      user: @authenticated_user,
      settings: {"facets" => facets}
    )
    desk.add_lexeme(word)
    desk
  end

  it "gives a tone-only desk a tone check rather than a plain swipe card" do
    desk = desk_with(%w[tone])

    get("/study", params: {mode: "desk", collection_id: desk.id})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("card-tone-quiz").or(include("card-speech")))
    expect(response.body).not_to(include("data-controller=\"swipe-card\""))
  end

  it "shows a handwriting card prompting from meaning, linking to the stroke trainer" do
    desk = desk_with(%w[writing])

    get("/study", params: {mode: "desk", collection_id: desk.id})

    expect(response.body).to(include(I18n.t("study.ask.writing")))
    expect(response.body).to(include(writing_path(lexeme_id: word.id)))
    expect(response.body).to(include("school").or(include("школа")))
  end

  it "grades the tone facet from inside the session" do
    desk = desk_with(%w[tone])
    get("/study", params: {mode: "desk", collection_id: desk.id})

    post(
      "/study/review",
      params: {lexeme_id: word.id, facet: "tone", rating: "good", elapsed_ms: 1200}
    )

    memory = LexemeMemory.owned_by(@authenticated_user).find_by(lexeme: word, facet: LexemeMemory.facets["tone"])
    expect(memory.reps).to(eq(1))
    expect(memory.state).not_to(eq("unseen"))
  end
end
