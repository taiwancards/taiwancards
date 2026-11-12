# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Studying textbook lesson decks by id" do
  let(:word) do
    create(
      :lexeme,
      kind: :character,
      text: "課",
      readings: {"pinyin" => "kè", "zhuyin" => "ㄎㄜˋ"},
      data: {"moe_index" => 1}
    )
  end

  let(:lesson) { Collection.create!(name: "Lesson 1", kind: :lesson).tap { |deck| deck.add_lexeme(word) } }
  let(:missing_id) { Collection.maximum(:id).to_i + 1000 }

  before do
    allow(Huayu::StrokeData).to(receive(:has?).and_return(true))
  end

  def study(collection_id) = get("/study", params: {mode: "collection", collection_id:})

  def shows_card? = response.body.include?("<input value=\"#{word.id}\" type=\"hidden\" name=\"lexeme_id\"")

  context("with a plain account") do
    it "deals no card from a lesson deck, just as for a deck that does not exist" do
      study(lesson.id)
      from_lesson = shows_card?

      study(missing_id)

      expect(response).to(have_http_status(:ok))
      expect(from_lesson).to(be(false))
      expect(LexemeMemory.owned_by(current_user).where(lexeme: word)).to(be_empty)
    end

    it "keeps the pronunciation trainer out of a lesson deck" do
      get("/pronunciation", params: {collection_id: lesson.id})

      expect(response).to(have_http_status(:ok))
      expect(response.body).not_to(include("collection_id=#{lesson.id}"))
    end

    it "keeps the writing trainer out of a lesson deck" do
      get("/writing", params: {collection_id: lesson.id})

      expect(response).to(have_http_status(:ok))
      expect(response.body).not_to(include("collection_id=#{lesson.id}"))
    end

    it "does not resume a sitting pointed at a lesson deck" do
      Current.user = current_user

      expect(Study::Run.resume("mode" => "collection", "col" => lesson.id).collection).to(be_nil)
    end
  end

  context("with an account cleared for textbook content") do
    before { sign_in(create(:user, restricted_content: true)) }

    it "studies the lesson deck" do
      study(lesson.id)

      expect(shows_card?).to(be(true))
    end

    it "opens the lesson deck in both trainers" do
      get("/pronunciation", params: {collection_id: lesson.id})
      expect(response.body).to(include("collection_id=#{lesson.id}"))

      get("/writing", params: {collection_id: lesson.id})
      expect(response.body).to(include("collection_id=#{lesson.id}"))
    end
  end

  it "still opens the learner's own deck and the TOCFL level decks" do
    own = Collection.create!(user: current_user, name: "Mine").tap { |deck| deck.add_lexeme(word) }
    level = Collection.create!(name: "TOCFL Novice 1", kind: :tocfl).tap { |deck| deck.add_lexeme(word) }

    [own, level].each do |deck|
      study(deck.id)
      expect(shows_card?).to(be(true))

      get("/pronunciation", params: {collection_id: deck.id})
      expect(response.body).to(include("collection_id=#{deck.id}"))

      get("/writing", params: {collection_id: deck.id})
      expect(response.body).to(include("collection_id=#{deck.id}"))
    end
  end
end
