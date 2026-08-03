# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audio on a study card" do
  let(:deck) { Collection.create!(kind: :manual, name: "Sound", user: current_user, settings: {"facets" => facets}) }
  let!(:clothes) do
    create(:lexeme, kind: :word, text: "衣服", readings: {"pinyin" => "yī fú"}, meanings: {"en" => "clothes"})
  end

  before { deck.add_lexemes([clothes.id]) }

  context("when the word has no recording of its own") do
    let(:facets) { %w[production] }

    it "stays silent rather than stitching single characters together" do
      allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))

      get(study_path(mode: "collection", collection_id: deck.id))

      expect(response).to(have_http_status(:ok))
      expect(response.body).not_to(include("data-audio-parts-value"))
      expect(response.body).not_to(include("data-audio-url-value"))
    end
  end

  context("when the whole word has its own clip") do
    let(:facets) { %w[production] }

    it "plays that single clip" do
      allow(Huayu::MoeAudio).to(
        receive(:for).and_return(
          Huayu::MoeAudio::Clip.new(scope: "words", id: "123456789", head_ms: 900, zhuyin: nil, pinyin: nil)
        )
      )

      get(study_path(mode: "collection", collection_id: deck.id))

      expect(response.body).to(include("data-audio-stop-ms-value=\"900\""))
      expect(response.body).not_to(include("data-audio-parts-value"))
    end
  end

  context("when only single characters are voiced") do
    let(:facets) { %w[listening] }

    it "offers no listening facet at all, because there is no clip of the whole word" do
      allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))

      get(study_path(mode: "collection", collection_id: deck.id))

      expect(Lexemes::Facets.for(clothes)).not_to(include("listening"))
      expect(response.body).not_to(include("data-audio-auto-ms-value"))
    end
  end
end
