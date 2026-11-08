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
    read_in("ru")
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

  describe "reading tools" do
    let(:tier) { Graded::Library.tiers.first }
    let(:text) { Graded::Library.texts(tier).first }
    let(:char) { text.lines.first.zh[/\p{Han}/] }
    let!(:lexeme) { create(:lexeme, kind: :character, text: char, meanings: {"en" => "a meaning"}) }

    before { Huayu::TextAnalyzer.reset_vocabulary! }

    after { Huayu::TextAnalyzer.reset_vocabulary! }

    def page = Nokogiri::HTML(response.body)

    it "puts the sentences ahead of the shelf of other texts" do
      get("/en/graded/#{tier}/#{text.id}")

      expect(response.body.index("reading-line")).to(be < response.body.index("data-controller=\"ribbon\""))
    end

    it "offers a translation for one sentence and the sentence-by-sentence mode" do
      get("/en/graded/#{tier}/#{text.id}")

      expect(page.css(".reading-line").size).to(eq(text.lines.size))
      expect(page.css(".reading-line [data-action='reading#toggleLine']").size).to(eq(text.lines.size))
      expect(page.css("[data-layer='focus']").size).to(eq(1))
      expect(page.css(".focus-bar [data-action='reading#next']").size).to(eq(1))
    end

    it "counts the words of the text already in study and marks them" do
      Lexemes::Activator.new(user: current_user).call(lexeme)

      get("/en/graded/#{tier}/#{text.id}")

      expect(page.css("[data-reading-target='saved']").text).to(eq("1"))
      expect(page.css(".word-saved[data-lexeme-id='#{lexeme.id}']")).not_to(be_empty)
    end

    it "adds every new word of the text and leaves it in study only once" do
      2.times { post("/en/graded/#{tier}/#{text.id}/words") }

      expect(response).to(redirect_to("/en/graded/#{tier}/#{text.id}"))
      expect(LexemeMemory.owned_by(current_user).where(lexeme:).active).not_to(be_empty)
      expect(LexemeMemory.owned_by(current_user).where(lexeme:).group(:facet).count.values).to(all(eq(1)))
    end

    context("for a visitor with no account", :no_auth) do
      it "asks for a sign-in instead of pretending to save a word" do
        get("/en/graded/#{tier}/#{text.id}")

        analyzer = page.at_css("[data-controller~='analyzer']")
        expect(analyzer["data-analyzer-activate-url-value"]).to(be_blank)
        expect(analyzer["data-analyzer-login-url-value"]).to(eq("/en/login"))
        expect(page.css("[data-reading-target='saved']")).to(be_empty)
        expect(page.css("form[action$='/words']")).to(be_empty)
        expect(response.headers["Cache-Control"]).to(include("public"))
      end

      it "keeps adding words behind the login" do
        post("/en/graded/#{tier}/#{text.id}/words")

        expect(response).to(redirect_to(login_path))
      end
    end
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
