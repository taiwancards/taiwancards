# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reference audio in the pronunciation trainer" do
  let!(:clothes) do
    create(:lexeme, kind: :word, text: "衣服", readings: {"pinyin" => "yī fú"}, meanings: {"en" => "clothes"})
  end

  def clip(id, head_ms, scope: "chars")
    Huayu::MoeAudio::Clip.new(scope:, id:, head_ms:, zhuyin: nil, pinyin: nil)
  end

  def parts_on_page
    JSON.parse(response.body[/data-pronunciation-audio-parts-value="([^"]*)"/, 1].to_s.gsub("&quot;", "\""))
  end

  it "hands over every syllable when the word is only voiced character by character" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))
    allow(Huayu::MoeAudio).to(receive(:per_character).and_return([clip("5838", 525), clip("0958", 796)]))

    get(pronunciation_path(lexeme_id: clothes.id))

    expect(response).to(have_http_status(:ok))
    expect(parts_on_page.map { |part| part["stop_ms"] }).to(eq([525, 796]))
    expect(parts_on_page.map { |part| part["url"] }.uniq.size).to(eq(2))
  end

  it "hands over a single clip when the whole word is voiced" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(clip("W1", 1003, scope: "words")))

    get(pronunciation_path(lexeme_id: clothes.id))

    expect(response.body).to(include("data-pronunciation-audio-stop-value=\"1003\""))
    expect(response.body[/data-pronunciation-audio-parts-value="([^"]*)"/, 1]).to(be_blank)
  end

  it "offers the prelisten toggle only when there is something to play" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))
    allow(Huayu::MoeAudio).to(receive(:per_character).and_return([]))

    get(pronunciation_path(lexeme_id: clothes.id))

    expect(response.body).not_to(include(I18n.t("pronunciation.prelisten")))
  end

  it "plays the same thing the study card plays" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))
    allow(Huayu::MoeAudio).to(receive(:per_character).and_return([clip("5838", 525), clip("0958", 796)]))

    get(pronunciation_path(lexeme_id: clothes.id))
    trainer = parts_on_page

    deck = Collection.create!(kind: :manual, name: "Sound", user: current_user, settings: {"facets" => %w[production]})
    deck.add_lexemes([clothes.id])
    get(study_path(mode: "collection", collection_id: deck.id))
    card = JSON.parse(response.body[/data-audio-parts-value="([^"]*)"/, 1].to_s.gsub("&quot;", "\""))

    expect(trainer).to(eq(card))
  end
end
