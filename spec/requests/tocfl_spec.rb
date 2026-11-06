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

  it "pins the marked entry above the list" do
    get("/tocfl/#{collection.id}?mark=%E9%9B%BB%E8%85%A6")
    expect(response.body).to(include(I18n.t("levels.marked")))
    expect(response.body).to(include("電腦"))
  end

  describe "the guide to the exam", :no_auth do
    it "shows every level with its pass marks to a visitor, from the shared cache" do
      get("/tocfl/exam")

      expect(response).to(have_http_status(:ok))
      expect(response.headers["Cache-Control"]).to(include("public"))
      page = Nokogiri::HTML(response.body)
      rows = page.css("tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
      expect(rows.size).to(eq(Huayu::TocflExam::LEVELS.size))
      expect(rows.last).to(include("精通級", "C2", "655", "690"))
    end

    it "is linked from the readiness page and reads in every language" do
      get("/tocfl")
      expect(response.body).to(include("/en/tocfl/exam"))

      %w[ru vi].each do |code|
        get("/#{code}/tocfl/exam")

        expect(response.body).to(include(I18n.t("tocfl.exam.title", locale: code)), code)
      end
    end
  end
end
