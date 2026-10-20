# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phrases" do
  it "lists the first scene by default" do
    get(phrases_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("不會"))
  end

  it "filters by scene" do
    get(phrases_path(scene: "drinks"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("甜度冰塊"))
    expect(response.body).not_to(include("借過"))
  end

  it "filters by role" do
    get(phrases_path(scene: "store", role: "staff"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("有載具嗎"))
  end

  it "falls back to the first scene when the slug is unknown" do
    get(phrases_path(scene: "nope"))

    expect(response).to(have_http_status(:ok))
  end

  it "renders the fillers of a closed slot and the localized label of an open one" do
    get(phrases_path(scene: "drinks"))

    expect(response.body).to(include("半糖"))
    expect(response.body).to(include("drink"))
  end

  it "links a pattern to the dictionary entries its words resolve to" do
    create(:lexeme, kind: :word, text: "廁所", meanings: {"en" => "restroom"})

    get(phrases_path(scene: "restroom"))

    expect(response.body).to(include(dict_entry_path(text: "廁所")))
  end

  it "leaves a word out of the chips when no entry exists for it" do
    get(phrases_path(scene: "restroom"))

    expect(response.body).not_to(include(dict_entry_path(text: "廁所")))
  end

  it "counts the patterns of every scene in the navigation" do
    get(phrases_path)

    expect(response.body).to(include(Huayu::TaiwanPhrases.counts["store"].to_s))
  end

  it "records the run so the roadmap step completes" do
    expect { get(phrases_path) }
      .to(change { @authenticated_user.reload.practice_runs["phrases"].to_i }.from(0).to(1))
  end

  describe "playing a scene" do
    let(:dialogue) { Huayu::TaiwanPhrases.dialogue("store") }

    it "links the scene to its dialogue" do
      get(phrases_path(scene: "store"))

      expect(response.body).to(include(phrase_dialogue_path(scene: "store")))
    end

    it "lays out every step with its readings, hiding all but the first", :no_auth do
      get(phrase_dialogue_path(scene: "store"))

      page = Nokogiri::HTML(response.body)
      steps = page.css("[data-dialogue-target='step']")
      expect(steps.size).to(eq(dialogue.steps.size))
      expect(steps.first["hidden"]).to(be_nil)
      expect(steps.drop(1)).to(all(satisfy { |step| step.key?("hidden") }))
      expect(page.css("[data-dialogue-target='choice']").size).to(eq(dialogue.steps.sum { |step| step.choices.size }))
      expect(page.css(".zy-line")).not_to(be_empty)
      expect(response.headers["Cache-Control"]).to(include("public"))
    end

    it "sends an unknown scene back to the phrasebook" do
      get(phrase_dialogue_path(scene: "nowhere"))

      expect(response).to(redirect_to(phrases_path))
    end
  end
end
