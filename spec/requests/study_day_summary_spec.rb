# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Study day summary" do
  it "closes a finished session with today's numbers and tomorrow's load" do
    user = @authenticated_user
    word = create(:lexeme, kind: :word, text: "明天")
    memory = LexemeMemory.create!(
      user:,
      lexeme: word,
      facet: :recognition,
      state: :review,
      due_at: 1.day.from_now.noon,
      activated_at: 1.day.ago
    )
    LexemeReview.create!(
      user:,
      lexeme: word,
      lexeme_memory: memory,
      facet: :recognition,
      rating: 3,
      reviewed_at: 1.minute.ago,
      state_before: LexemeMemory.states[:unseen]
    )

    get("/study", params: {mode: "decks"})

    expect(response.body).to(include("reviews today", "new words", "day streak", "1 card is waiting tomorrow."))
  end

  it "stays quiet before the first review of the day" do
    get("/study", params: {mode: "decks"})

    expect(response.body).not_to(include("reviews today"))
  end
end
