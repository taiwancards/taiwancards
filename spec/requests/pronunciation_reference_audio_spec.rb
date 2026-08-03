# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reference audio in the pronunciation trainer" do
  let!(:clothes) do
    create(:lexeme, kind: :word, text: "衣服", readings: {"pinyin" => "yī fú"}, meanings: {"en" => "clothes"})
  end

  def clip(id, head_ms, scope: "chars")
    Huayu::MoeAudio::Clip.new(scope:, id:, head_ms:, zhuyin: nil, pinyin: nil)
  end

  before { VoiceProfile.create!(user: @authenticated_user, f3_ref: 2900, calibrated_at: Time.current) }

  it "hands over a single clip when the whole word is voiced" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(clip("123456789", 1003, scope: "words")))

    get(pronunciation_path(lexeme_id: clothes.id))

    expect(response.body).to(include("data-pronunciation-audio-stop-value=\"1003\""))
    expect(response.body).not_to(include("data-pronunciation-audio-parts-value"))
  end

  it "offers the prelisten toggle only when there is something to play" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))

    get(pronunciation_path(lexeme_id: clothes.id))

    expect(response.body).not_to(include(I18n.t("pronunciation.prelisten")))
  end

  it "plays the same clip the study card plays" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(clip("123456789", 1003, scope: "words")))

    get(pronunciation_path(lexeme_id: clothes.id))
    trainer = response.body[/data-pronunciation-audio-url-value="([^"]*)"/, 1]

    deck = Collection.create!(kind: :manual, name: "Sound", user: current_user, settings: {"facets" => %w[production]})
    deck.add_lexemes([clothes.id])
    get(study_path(mode: "collection", collection_id: deck.id))
    card = response.body[/data-audio-url-value="([^"]*)"/, 1]

    expect(trainer).to(be_present)
    expect(card).to(eq(trainer))
  end
end
