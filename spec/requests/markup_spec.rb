# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sentence markup" do
  let(:source) { ContentSource.create!(slug: "open", name: "Open", license_commercial: true, attribution: "open") }
  let(:store) { Pathname(Dir.mktmpdir("sentence-glosses")).join("sentence_glosses.jsonl") }

  before do
    stub_const("#{Huayu::SentenceGlossStore}::PATH", store)
    allow(Huayu::SentenceGlossStore).to(receive(:put).and_call_original)
    sign_in(create(:user, :admin))
  end

  after { store.dirname.rmtree if store.dirname.exist? }

  def stored_sentence = create(
    :lexeme,
    :sentence,
    text: "我喝茶。",
    meanings: {"en" => "I drink tea."},
    content_source: source
  )

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

  it "lets an administrator delete a sentence and forget its translations" do
    doomed = stored_sentence

    delete("/markup/#{doomed.id}")

    expect(response).to(have_http_status(:found))
    expect(Lexeme.exists?(doomed.id)).to(be(false))
    expect(Huayu::SentenceGlossStore).to(have_received(:put).with("我喝茶。", en: nil, ru: nil))
  end

  context("outside a local environment") do
    before { allow(Rails.env).to(receive(:local?).and_return(false)) }

    it "answers not found on every route, even to an administrator" do
      kept = stored_sentence

      get("/markup")
      expect(response).to(have_http_status(:not_found))
      get("/markup/#{kept.id}")
      expect(response).to(have_http_status(:not_found))
      patch("/markup/#{kept.id}", params: {en: "Changed."})
      expect(response).to(have_http_status(:not_found))
      delete("/markup/#{kept.id}")
      expect(response).to(have_http_status(:not_found))

      expect(kept.reload.meanings).to(eq({"en" => "I drink tea."}))
      expect(Huayu::SentenceGlossStore).not_to(have_received(:put))
    end

    it "answers not found to a guest instead of asking to sign in", :no_auth do
      reset!

      get("/markup")

      expect(response).to(have_http_status(:not_found))
    end
  end

  it "refuses a plain account, and the sentence survives" do
    kept = stored_sentence
    sign_in(create(:user))

    delete("/markup/#{kept.id}")

    expect(response).to(redirect_to(root_path))
    expect(flash[:alert]).to(eq(I18n.t("access.admin_denied")))
    expect(Lexeme.exists?(kept.id)).to(be(true))
    expect(Huayu::SentenceGlossStore).not_to(have_received(:put))
  end
end
