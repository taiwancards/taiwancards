# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TOCFL" do
  let!(:collection) do
    Collection.create!(kind: :tocfl, name: "TOCFL Band A · A1", level_tag: "A1", position: 2)
  end

  let!(:studied) { create(:lexeme, text: "照片", readings: {"pinyin" => "zhàopiàn"}) }
  let!(:fresh) { create(:lexeme, text: "電腦", readings: {"pinyin" => "diànnǎo"}) }

  before do
    collection.add_lexeme(studied)
    collection.add_lexeme(fresh)
    Collection.reset_counters(collection.id, :collection_items)
    LexemeMemory.create!(
      lexeme: studied,
      facet: :recognition,
      state: :review,
      activated_at: Time.current,
      user: Current.user
    )
  end

  it "shows readiness computed over global progress" do
    get("/tocfl")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("TOCFL Band A · A1", "1 / 2 known"))
  end

  it "lists a level with a study link and marks known words" do
    get("/tocfl/#{collection.id}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("mode=collection"))
    expect(response.body).to(include("照", "電"))
  end
end
