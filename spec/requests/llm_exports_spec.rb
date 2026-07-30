# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LLM exports" do
  before { Rails.application.load_seed }

  def activate(text, stability: nil, data: {})
    lexeme = create(:lexeme, text:, meanings: {"en" => "meaning of #{text}"}, data:)
    LexemeMemory.create!(
      lexeme:,
      user: @authenticated_user,
      facet: :recognition,
      activated_at: Time.current,
      state: stability ? :review : :unseen,
      stability:
    )
    lexeme
  end

  it "splits activated lexemes into known and learning" do
    activate("歡迎", stability: 40.0, data: {"tocfl_level" => "A1"})
    activate("謝謝")

    get("/export")
    payload = response.parsed_body

    expect(payload["known_words"]).to(
      eq([{"word" => "歡迎", "translation" => "meaning of 歡迎", "level" => "A1"}])
    )
    expect(payload["learning_words"]).to(eq([{"word" => "謝謝", "translation" => "meaning of 謝謝"}]))
  end

  it "leaves out lexemes nobody activated" do
    create(:lexeme, text: "冷門")

    get("/export")

    words = response.parsed_body.values_at("known_words", "learning_words").flatten
    expect(words.pluck("word")).not_to(include("冷門"))
  end
end
