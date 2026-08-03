# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mistakes" do
  it "renders the empty notebook" do
    get("/mistakes")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Mistake notebook"))
  end

  it "lists recent lapses and offers a redrill session" do
    lexeme = create(:lexeme, text: "學校", meanings: {"en" => "school"})
    memory = LexemeMemory.create!(
      lexeme:,
      facet: :recognition,
      user: current_user,
      state: :learning,
      activated_at: 1.day.ago
    )
    LexemeReview.create!(
      lexeme:,
      lexeme_memory: memory,
      user: current_user,
      facet: :recognition,
      rating: Fsrs::Scheduler::RATINGS.fetch(:again),
      reviewed_at: 1.day.ago
    )

    get("/mistakes")

    expect(response.body).to(include("學校"))
    expect(response.body).to(include("/study?mode=mistakes"))
  end
end
