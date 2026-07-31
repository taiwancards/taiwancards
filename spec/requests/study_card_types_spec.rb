# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card types per facet" do
  let(:deck) { Collection.create!(kind: :manual, name: "Cards", user: current_user, settings: {"facets" => facets}) }

  def study(mode: "collection")
    get(study_path(mode:, collection_id: deck.id))
  end

  context("with a handwriting facet") do
    let(:facets) { %w[writing] }

    before do
      allow(Huayu::WritingTarget).to(receive(:writable?).and_return(true))
      allow(Huayu::StrokeData).to(receive(:has?).and_return(true))
    end

    it "draws the quiz instead of a swipe card and offers hint and skip" do
      deck.add_lexemes([create(:lexeme, kind: :character, text: "學", meanings: {"en" => "learn"}).id])

      study

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("card-writing"))
      expect(response.body).to(include(I18n.t("study.writing.hint")))
      expect(response.body).to(include(I18n.t("study.writing.skip")))
    end

    it "does not arm the swipe controller on a handwriting card" do
      deck.add_lexemes([create(:lexeme, kind: :character, text: "校", meanings: {"en" => "school"}).id])

      study

      expect(response.body).not_to(include("data-controller=\"swipe-card\""))
    end

    it "grades a skipped card as a miss so it comes back" do
      lexeme = create(:lexeme, kind: :character, text: "書", meanings: {"en" => "book"})
      deck.add_lexemes([lexeme.id])
      study

      post(
        study_review_path,
        params: {lexeme_id: lexeme.id, facet: "writing", rating: "again", session_id: session[:study]["sid"]},
        as: :turbo_stream
      )

      review = LexemeReview.find_by(lexeme_id: lexeme.id, facet: LexemeMemory.facets["writing"])
      expect(review.rating).to(eq(Fsrs::Scheduler::RATINGS[:again]))
    end
  end

  context("with a listening facet") do
    let(:facets) { %w[listening] }

    it "starts the clip on its own shortly after the card appears" do
      lexeme = create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"})
      allow(Huayu::MoeAudio).to(
        receive(:for).and_return(
          Huayu::MoeAudio::Clip.new(scope: "words", id: "A1", head_ms: 0, zhuyin: nil, pinyin: nil)
        )
      )
      deck.add_lexemes([lexeme.id])

      study

      expect(response.body).to(include("data-audio-auto-ms-value=\"#{StudyHelper::AUTOPLAY_MS}\""))
    end
  end

  context("with a plain recognition facet") do
    let(:facets) { %w[recognition] }

    it "keeps the swipe card" do
      deck.add_lexemes([create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}).id])

      study

      expect(response.body).to(include("data-controller=\"swipe-card\""))
      expect(response.body).not_to(include("card-writing"))
    end
  end
end
