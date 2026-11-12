# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Vocabulary export for a language model" do
  def remember(lexeme, owner: current_user, state: :review, stability: 30, facet: :recognition, activated_at: 1.day.ago)
    LexemeMemory.create!(lexeme:, user: owner, facet:, state:, stability:, activated_at:)
  end

  def exported
    get("/export")
    response.parsed_body
  end

  it "lists a word as known once every reviewed side of it is mature" do
    word = create(:lexeme, text: "學校", meanings: {"en" => "school"}, data: {"tocfl_level" => "Novice1"})
    remember(word)
    remember(word, facet: :production, stability: 45)

    expect(exported["known_words"]).to(eq([{"word" => "學校", "translation" => "school", "level" => "Novice1"}]))
    expect(exported["learning_words"]).to(be_empty)
  end

  it "keeps a word among the ones being learned while one reviewed side is still young" do
    word = create(:lexeme, text: "老師")
    remember(word)
    remember(word, facet: :production, stability: 3)

    expect(exported["learning_words"].pluck("word")).to(eq(["老師"]))
    expect(exported["known_words"]).to(be_empty)
  end

  it "counts a word that has only been started as being learned" do
    remember(create(:lexeme, text: "便當"), state: :learning, stability: nil)

    expect(exported["learning_words"]).to(eq([{"word" => "便當", "translation" => "meaning"}]))
  end

  it "leaves out a word that was never activated" do
    remember(create(:lexeme, text: "捷運"), state: :unseen, stability: nil, activated_at: nil)

    expect(exported.values_at("known_words", "learning_words")).to(all(be_empty))
  end

  it "judges a word by this learner's memories alone" do
    word = create(:lexeme, text: "夜市")
    remember(word, stability: 2)
    remember(word, owner: create(:user), stability: 90)

    expect(exported["learning_words"].pluck("word")).to(eq(["夜市"]))
  end

  it "never reads another learner's memories" do
    word = create(:lexeme, text: "夜市")
    remember(word)
    remember(word, owner: create(:user))

    report = count_queries { get("/export") }

    expect(report.statements.grep(/FROM "lexeme_memories"/)).to(all(include("\"lexeme_memories\".\"user_id\" =")))
  end

  it "turns a guest away", :no_auth do
    get("/export")

    expect(response).not_to(be_successful)
  end
end
