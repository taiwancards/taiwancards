# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rating kept pronunciation recordings", :aggregate_failures do
  let(:owner) { create(:user, restricted_content: true) }

  let(:syllables) do
    [
      {
        "key" => "hao3",
        "index" => 0,
        "char" => "好",
        "zhuyin" => "ㄏㄠˇ",
        "level" => "green",
        "overall" => 90,
        "cells" => {"tone" => 88}
      },
      {
        "key" => "shi4",
        "index" => 1,
        "char" => "事",
        "zhuyin" => "ㄕˋ",
        "level" => "amber",
        "overall" => 71,
        "cells" => {"tone" => 64}
      }
    ]
  end

  let!(:recording) do
    PronunciationRecording.create!(
      user: owner,
      text: "好事",
      syllable_keys: %w[hao3 shi4],
      syllables: syllables,
      audio: "bytes",
      content_type: "audio/webm"
    )
  end

  it "keeps the page away from an ordinary learner" do
    get("/ru/pronunciation/judge")

    expect(response).to(redirect_to(root_path))
  end

  context("as the owner") do
    before { sign_in(owner) }

    it "lists what is waiting to be rated" do
      get("/ru/pronunciation/judge")

      expect(response.body).to(include("好事"))
    end

    it "does not put the engine's verdict where it can be read before deciding" do
      get("/ru/pronunciation/judge")
      visible = ActionController::Base.helpers.strip_tags(response.body.split("<details").first)

      expect(visible).not_to(include("90"))
    end

    it "does keep the engine's verdict on the page, behind the reveal" do
      get("/ru/pronunciation/judge")

      expect(response.body.split("<details").last).to(include("90"))
    end

    it "serves the audio back for listening" do
      get("/ru/pronunciation/judge/#{recording.id}/audio")

      expect([response.media_type, response.body]).to(eq(["audio/webm", "bytes"]))
    end

    it "records an acceptance" do
      patch("/ru/pronunciation/judge/#{recording.id}", params: {verdict: "accepted"})

      expect(recording.reload).to(have_attributes(verdict: "accepted", rated_at: be_present))
    end

    it "records which syllable was rejected" do
      patch("/ru/pronunciation/judge/#{recording.id}", params: {verdict: "rejected", rejected: %w[1]})

      expect(recording.reload).to(have_attributes(verdict: "rejected", rejected_indices: [1]))
    end

    it "refuses a verdict it does not know" do
      patch("/ru/pronunciation/judge/#{recording.id}", params: {verdict: "brilliant"})

      expect(recording.reload.verdict).to(eq("unsure"))
    end

    it "drops a recording that is not worth rating" do
      delete("/ru/pronunciation/judge/#{recording.id}")

      expect(PronunciationRecording.count).to(be_zero)
    end

    it "stops offering a recording once it has been rated" do
      patch("/ru/pronunciation/judge/#{recording.id}", params: {verdict: "accepted"})
      get("/ru/pronunciation/judge")

      expect(response.body).not_to(include("好事"))
    end
  end
end
