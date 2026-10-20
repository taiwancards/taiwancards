# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Graded reader" do
  it "lists the tiers that have texts" do
    get("/en/graded")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Graded TW Reader"))
    Graded::Library.tiers.each { |tier| expect(response.body).to(include("/graded/#{tier}")) }
  end

  it "opens the first text of a tier and shows its coverage" do
    tier = Graded::Library.tiers.first
    text = Graded::Library.texts(tier).first

    get("/en/graded/#{tier}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(text.lines.first.name(:en)))
    expect(response.body).to(include("inside the tier"))
  end

  it "opens a named text and lists its glosses" do
    tier = Graded::Library.tiers.first
    text = Graded::Library.texts(tier).last

    get("/ru/graded/#{tier}/#{text.id}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(text.notes.first.name(:ru)))
  end

  it "sends an unknown tier back to the index" do
    get("/en/graded/nope")

    expect(response).to(redirect_to("/en/graded"))
  end

  it "links every tagged line to its grammar lessons behind a toggle" do
    text = Graded::Library.all.find { |entry| entry.lines.any? { |line| line.grammar.any? } }
    lesson = text.lines.flat_map(&:grammar_lessons).first

    get("/en/graded/#{text.tier}/#{text.id}")

    expect(response.body).to(include("data-layer=\"grammar\""))
    expect(response.body).to(include("/en/grammar/#{lesson.slug}"))
    expect(Nokogiri::HTML(response.body).css(".layer-grammar")).not_to(be_empty)
  end

  describe "reading progress" do
    let(:tier) { Graded::Library.tiers.first }
    let(:text) { Graded::Library.texts(tier).first }
    let(:following) { Graded::Library.following(text) }

    it "marks a text as read once and moves on to the next one" do
      2.times { post("/en/graded/#{tier}/#{text.id}/done") }

      expect(response).to(redirect_to("/en/graded/#{following.tier}/#{following.id}"))
      expect(GradedCompletion.where(user: current_user, text_id: text.id).count).to(eq(1))
    end

    it "keeps the best quiz score, counted against the quiz the server builds" do
      post("/en/graded/#{tier}/#{text.id}/done", params: {score: 99})
      post("/en/graded/#{tier}/#{text.id}/done", params: {score: 1})

      completion = GradedCompletion.find_by(user: current_user, text_id: text.id)
      expect(completion.total).to(be_between(3, 5))
      expect(completion.score).to(eq(completion.total))
    end

    it "offers the quiz with its score wired to the finish form" do
      get("/en/graded/#{tier}/#{text.id}")

      page = Nokogiri::HTML(response.body)
      expect(page.css("[data-controller='course-task']").size).to(be >= 3)
      expect(page.at_css("input[name='score']")["form"]).to(eq(page.at_css("form[action$='/done']")["id"]))
    end

    it "shows the read mark and what comes next" do
      GradedCompletion.record(user: current_user, text_id: text.id)

      get("/en/graded/#{tier}/#{text.id}")

      expect(Nokogiri::HTML(response.body).css("span").map { |span| span.text.strip }).to(include("Read"))
      expect(response.body).to(include("Up next"))
      expect(response.body).to(include(following.zh))
    end

    it "offers the first unread text of the suggested tier on the index" do
      GradedCompletion.record(user: current_user, text_id: text.id)

      get("/en/graded")

      expect(response.body).to(include("Continue reading"))
      expect(response.body).to(include("/en/graded/#{following.tier}/#{following.id}"))
      expect(response.body).to(include("Your level"))
    end

    it "lets a guest read on without a form", :no_auth do
      get("/en/graded/#{tier}/#{text.id}")

      expect(response.body).not_to(include("/done"))
      expect(response.body).to(include("to keep track of what you have read"))
      expect(response.headers["Cache-Control"]).to(include("public"))
    end

    it "keeps a guest from recording progress", :no_auth do
      post("/en/graded/#{tier}/#{text.id}/done")

      expect(GradedCompletion.count).to(eq(0))
    end
  end
end
