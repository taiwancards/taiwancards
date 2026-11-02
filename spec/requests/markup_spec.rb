# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sentence markup" do
  let(:source) { ContentSource.create!(slug: "open", name: "Open", license_commercial: true, attribution: "open") }
  let(:store) { Pathname(Dir.mktmpdir("sentence-glosses")).join("sentence_glosses.jsonl") }

  before do
    stub_const("#{Huayu::SentenceGlossStore}::PATH", store)
    sign_in(create(:user, :admin))
  end

  after { store.dirname.rmtree if store.dirname.exist? }

  it "keeps the Vietnamese translation when the English and Russian are edited" do
    sentence = create(
      :lexeme,
      kind: :sentence,
      text: "我喝茶。",
      meanings: {"en" => "I drink.", "vi" => "Tôi uống trà."},
      content_sources: [source]
    )

    patch("/markup/#{sentence.id}", params: {en: "I drink tea.", ru: "Я пью чай."})

    expect(sentence.reload.meanings).to(
      eq({"vi" => "Tôi uống trà.", "en" => "I drink tea.", "ru" => "Я пью чай."})
    )
    expect(Huayu::SentenceGlossStore.index.fetch("我喝茶。").vi).to(eq("Tôi uống trà."))
  end
end
