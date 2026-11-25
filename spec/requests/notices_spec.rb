# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notices", :no_auth do
  def html = Nokogiri::HTML5(response.body)

  def sheets = html.css("article.notice-sheet, article.form-sheet")

  let(:notices) { Huayu::TaiwanNotices }
  let(:form) { notices.all.find(&:form?) }

  it "lists every entry on the landing page, grouped by life situation" do
    get("/en/notices")

    expect(response).to(have_http_status(:ok))
    notices.situations.each do |situation|
      expect(response.body).to(include(notices_situation_path(situation: situation, locale: "en")))
    end

    notices.all.each { |notice| expect(response.body).to(include("##{notice.id}")) }
    expect(sheets).to(be_empty)
  end

  it "shows only the entries of the chosen situation" do
    get("/en/notices/building")

    expect(response).to(have_http_status(:ok))
    expect(sheets.map { |sheet| sheet["id"] }).to(eq(notices.in_situation("building").map(&:id)))
  end

  it "makes the words of a notice clickable" do
    get("/en/notices/building")

    expect(response.body.scan("data-analyzer-target=\"word\"").size).to(be > 50)
  end

  it "prints the document furniture a Taiwanese notice carries" do
    get("/en/notices/building")

    expect(response.body).to(include("notice-kind"))
    expect(response.body).to(include("notice-seal"))
    expect(response.body).to(include("Subject:"))
  end

  it "sets the localized labels in the interface language, not in the notice's Chinese face" do
    get("/vi/notices/building")

    labels = html.css(".notice-label")
    expect(labels).not_to(be_empty)
    expect(labels.map { |label| label["lang"] }.uniq).to(eq(["vi"]))
  end

  it "carries the translation of every line for the reader" do
    get("/ru/notices/building")

    expect(response.body).to(
      include("Дымовые окна в лестничных холлах давно в эксплуатации")
    )
  end

  it "draws a form field by field, with the value, the explanation and the line that matters" do
    get("/en/notices/#{form.situation}")

    sheet = html.at_css("article.form-sheet##{form.id}")
    rows = sheet.css(".form-row")
    expect(rows.size).to(eq(form.fields.reject(&:heading?).size))
    expect(sheet.css(".form-label [data-analyzer-target='word']")).not_to(be_empty)
    expect(sheet.css(".form-value [data-analyzer-target='word']")).not_to(be_empty)
    expect(sheet.text).to(include(form.fields.find(&:key?).note(:en)))
    expect(sheet.css(".form-key .form-key-badge").map(&:text).uniq).to(eq(["The line that matters"]))
    expect(sheet.css(".notice-seal")).to(be_empty)
  end

  it "falls back to English, marked as English, where an explanation awaits translation" do
    with_notice_drafts do
      get("/id/notices/health")

      note = html.at_css("article#ready .form-note")
      expect(note.text).to(eq("Yours."))
      expect(note["lang"]).to(eq("en"))
    end
  end

  it "sends the old category filter to the situation that now holds it" do
    get("/en/notices", params: {category: "safety"})

    expect(response).to(redirect_to("/en/notices/building"))
    expect(response).to(have_http_status(:moved_permanently))
  end

  it "ignores a category nobody publishes" do
    get("/en/notices", params: {category: "nonsense"})

    expect(response).to(have_http_status(:ok))
  end

  it "answers 404 for a situation that does not exist" do
    get("/en/notices/nonsense")

    expect(response).to(have_http_status(:not_found))
  end

  it "shows no draft to a reader" do
    with_notice_drafts do
      get("/en/notices")
      expect(response.body).to(include("#ready"))
      expect(response.body).not_to(include("#unsure"))

      get("/en/notices/health")
      expect(sheets.map { |sheet| sheet["id"] }).to(eq(["ready"]))

      get("/en/notices/school")
      expect(response).to(have_http_status(:not_found))
    end
  end

  it "links every word of a page in one pass, however many lines the page has" do
    get("/en/notices/health")
    counts = %w[health building].to_h do |situation|
      queries = 0
      counter = -> (*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get("/en/notices/#{situation}") }
      [situation, queries]
    end

    expect(counts["building"]).to(eq(counts["health"]))
  end
end
