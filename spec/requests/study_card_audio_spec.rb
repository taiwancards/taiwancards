# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audio on a study card" do
  let(:deck) { Collection.create!(kind: :manual, name: "Sound", user: current_user, settings: {"facets" => facets}) }
  let!(:clothes) do
    create(:lexeme, kind: :word, text: "衣服", readings: {"pinyin" => "yī fú"}, meanings: {"en" => "clothes"})
  end

  def clip(id, head_ms)
    Huayu::MoeAudio::Clip.new(scope: "chars", id:, head_ms:, zhuyin: nil, pinyin: nil)
  end

  def parts_on_page
    JSON.parse(response.body[/data-audio-parts-value="([^"]*)"/, 1].to_s.gsub("&quot;", "\""))
  end

  before do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))
    allow(Huayu::MoeAudio).to(receive(:per_character).and_return([clip("5838", 525), clip("0958", 796)]))
    deck.add_lexemes([clothes.id])
  end

  context("when the word only has a clip per character") do
    let(:facets) { %w[production] }

    it "carries every syllable, not just the first" do
      get(study_path(mode: "collection", collection_id: deck.id))

      expect(response).to(have_http_status(:ok))
      expect(parts_on_page.size).to(eq(2))
      expect(parts_on_page.map { |part| part["stop_ms"] }).to(eq([525, 796]))
    end

    it "points the parts at different clips" do
      get(study_path(mode: "collection", collection_id: deck.id))

      expect(parts_on_page.map { |part| part["url"] }.uniq.size).to(eq(2))
    end
  end

  context("when the whole word has its own clip") do
    let(:facets) { %w[production] }

    it "plays the single clip and offers no parts" do
      allow(Huayu::MoeAudio).to(
        receive(:for).and_return(
          Huayu::MoeAudio::Clip.new(scope: "words", id: "W1", head_ms: 900, zhuyin: nil, pinyin: nil)
        )
      )

      get(study_path(mode: "collection", collection_id: deck.id))

      expect(response.body).to(include("data-audio-stop-ms-value=\"900\""))
      expect(response.body[/data-audio-parts-value="([^"]*)"/, 1]).to(be_blank)
    end
  end

  context("when only single characters are voiced") do
    let(:facets) { %w[listening] }

    it "offers no listening facet at all, because there is no clip of the whole word" do
      get(study_path(mode: "collection", collection_id: deck.id))

      expect(Lexemes::Facets.for(clothes)).not_to(include("listening"))
      expect(response.body).not_to(include("data-audio-auto-ms-value"))
    end
  end
end
