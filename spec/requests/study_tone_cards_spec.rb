# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tone cards" do
  let(:deck) { Collection.create!(kind: :manual, name: "Tones", user: current_user, settings: {"facets" => %w[tone]}) }
  let!(:word) do
    create(:lexeme, kind: :word, text: "學校", readings: {"pinyin" => "xué xiào"}, meanings: {"en" => "school"})
  end

  def study
    get(study_path(mode: "collection", collection_id: deck.id))
  end

  before do
    deck.add_lexemes([word.id])
    warm_up!
  end

  it "starts with the tone quiz, not the microphone" do
    study

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("card-tone-quiz"))
    expect(response.body).to(include(I18n.t("study.tone_quiz.ask")))
  end

  it "offers four answers, one per swipe direction" do
    study

    %w[up down left right].each { |direction| expect(response.body).to(include("data-direction=\"#{direction}\"")) }
    expect(response.body.scan(/data-correct="true"/).size).to(eq(1))
  end

  it "shows the options in zhuyin and in pinyin, one syllable per unbreakable span" do
    study

    expect(response.body).to(include("ㄒㄩㄝˊ"))
    expect(response.body).to(include(">xué<"))
    expect(response.body).to(include(">xiào<"))
  end

  it "switches to the speaking check on the next round" do
    LexemeMemory.create!(lexeme: word, user: current_user, facet: :tone, activated_at: Time.current, reps: 1)

    study

    expect(response.body).to(include("card-speech"))
    expect(response.body).to(include(I18n.t("study.speech.ask")))
  end

  it "lets the person retry and advance on their own from the speaking check" do
    LexemeMemory.create!(lexeme: word, user: current_user, facet: :tone, activated_at: Time.current, reps: 1)

    study

    expect(response.body).to(include(I18n.t("study.speech.record")))
    expect(response.body).to(include(I18n.t("study.speech.next")))
    expect(response.body).to(include("data-card-speech-good-at-value=\"#{StudyHelper::SPEECH_GOOD_AT}\""))
  end

  it "starts the recorder on its own after the configured delay" do
    LexemeMemory.create!(lexeme: word, user: current_user, facet: :tone, activated_at: Time.current, reps: 1)

    study

    expect(response.body).to(include("data-card-speech-auto-ms-value=\"#{Setting.instance.pron_auto[:delay_ms]}\""))
  end

  it "never asks for a recording from a voice the app has not measured yet" do
    VoiceProfile.where(user: current_user).destroy_all
    LexemeMemory.create!(lexeme: word, user: current_user, facet: :tone, activated_at: Time.current, reps: 1)

    study

    expect(response.body).not_to(include("card-speech"))
    expect(response.body).to(include("card-tone-quiz"))
  end

  it "falls back to the plain swipe card when the word has no readable syllables" do
    silent = create(:lexeme, kind: :word, text: "無音", readings: {}, meanings: {"en" => "silent"})
    quiet = Collection.create!(kind: :manual, name: "Quiet", user: current_user, settings: {"facets" => %w[tone]})
    quiet.add_lexemes([silent.id])

    get(study_path(mode: "collection", collection_id: quiet.id))

    expect(response.body).to(include("data-controller=\"swipe-card\""))
  end

  it "grades a wrong tone answer as a miss" do
    study

    post(
      study_review_path,
      params: {lexeme_id: word.id, facet: "tone", rating: "again", session_id: session[:study]["sid"]},
      as: :turbo_stream
    )

    review = LexemeReview.find_by(lexeme_id: word.id, facet: LexemeMemory.facets["tone"])
    expect(review.rating).to(eq(Fsrs::Scheduler::RATINGS[:again]))
  end
end
