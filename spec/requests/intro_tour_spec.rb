# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Intro tour" do
  let(:user) { @authenticated_user }

  describe "the introduction" do
    before { user.update!(prefs: user.prefs.merge("intro_stage" => "running", "intro_step" => "overview")) }

    it "is a page of its own, with no overlay on top of it" do
      get("/intro")

      expect(response).to(have_http_status(:ok))
      expect(response.body).not_to(include("intro-tour"))
    end

    it "names every section it offers and links straight to it" do
      get("/intro")

      Intro::Highlights.compute.each do |block|
        expect(response.body).to(include(CGI.escapeHTML(I18n.t("intro.page.blocks.#{block.id}.title"))))
        expect(response.body).to(include("href=\"/en#{block.path}\""))
      end
    end

    it "counts what is really in the database rather than promising vaguely" do
      get("/intro")

      expect(response.body).to(include(I18n.t("intro.page.figures.lessons", value: 60)))
    end

    it "lets the reader finish it, and never nags with a skip" do
      get("/intro")

      expect(response.body).to(include(CGI.escapeHTML(I18n.t("intro.page.finish.cta"))))
      expect(response.body).not_to(include(I18n.t("intro.skip")))
    end
  end

  describe "a fresh account" do
    it "is asked whether it wants the introduction, not shown it unbidden" do
      get("/desk")

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("intro.setup.tour")))
      expect(response.body).not_to(include("intro-tour"))
    end

    it "is offered the tour rather than pushed through it" do
      expect(user.intro).to(be_pending)
      expect(user.intro).not_to(be_required)
    end
  end

  describe "someone who has already finished" do
    before { user.intro.finish! }

    it "is never shown the introduction again, whatever version they finished on" do
      [0, 1, 2, Intro::Map.version].each do |stamp|
        user.update!(prefs: user.prefs.merge("intro_version" => stamp))

        get("/desk")

        expect(response).to(have_http_status(:ok))
        expect(response.body).not_to(include("intro-tour"))
        expect(response.body).not_to(include(CGI.escapeHTML(I18n.t("intro.page.title"))))
      end
    end

    it "is left alone on every other page too" do
      get("/progress")

      expect(response).to(have_http_status(:ok))
    end

    it "shows nothing when the user is already on the current version" do
      user.update!(prefs: user.prefs.merge("intro_version" => Intro::Map.version))
      get("/desk")

      expect(response.body).not_to(include("intro-tour"))
    end
  end

  describe "the full guide" do
    before { user.intro.finish! }

    it "lists every chapter on the guide" do
      get(guide_path)

      Intro::Map.chapters.each do |chapter|
        expect(response.body).to(include(I18n.t("#{chapter.i18n_key}.title")))
      end
    end

    it "opens the page the chapter is about, without walking a menu first" do
      post("/intro/chapter/taiwan")

      expect(response).to(redirect_to("/en/everyday"))
    end

    it "opens every chapter straight onto its own page" do
      Intro::Map.chapters.each do |chapter|
        post("/intro/chapter/#{chapter.id}")

        expect(response).to(redirect_to("/en#{chapter.steps.first.path}"))
        delete("/intro/chapter")
      end
    end

    it "asks for no menu click anywhere in the guide" do
      actions = Intro::Map.chapters.flat_map(&:steps).map(&:advance)

      expect(actions).not_to(include("click"))
      expect(Intro::Map.chapters.flat_map(&:steps).map(&:lands_on).compact).to(be_empty)
    end

    it "hands the whole chapter to the page and never asks for a menu click" do
      post("/intro/chapter/taiwan")
      get("/everyday")

      chapter = Intro::Map.chapter("taiwan")
      payload = response.body[/data-intro-steps-value="([^"]*)"/, 1]
      steps = JSON.parse(CGI.unescapeHTML(payload.to_s))

      expect(steps.map { |step| step["id"] }).to(eq(chapter.steps.map(&:id)))
      expect(steps.map { |step| step["action"] }).not_to(include("click"))
      expect(response.body).to(include("data-intro-walkable-value=\"true\""))
    end

    it "asks the reader to tap rather than opening the page for them" do
      post("/intro/chapter/taiwan")
      get(guide_path)

      expect(response.body).to(include(CGI.escapeHTML(I18n.t("intro.click_target"))))
    end

    it "runs the chapter and lets the user leave at any point" do
      post("/intro/chapter/taiwan")
      get(guide_path)

      expect(response.body).to(include("intro-tour"))
      expect(response.body).to(include(I18n.t("intro.skip")))
    end

    it "remembers a finished chapter" do
      post("/intro/chapter/taiwan")
      delete("/intro/chapter", params: {completed: "1"})

      expect(user.reload.intro).to(be_chapter_done("taiwan"))
    end

    it "follows the reader when the page reports which step they reached" do
      chapter = Intro::Map.chapter("taiwan")
      post("/intro/chapter/taiwan")

      post("/intro/next", params: {step: chapter.steps.last.id}, headers: {"X-Requested-With" => "XMLHttpRequest"})

      expect(response).to(have_http_status(:no_content))
      get(guide_path)
      expect(response.body).to(include("data-intro-start-value=\"#{chapter.steps.last.id}\""))
    end

    it "steps back inside the chapter instead of touching the mandatory tour" do
      post("/intro/chapter/course")
      post("/intro/next")
      post("/intro/back")

      first = Intro::Map.chapter("course").steps.first
      get("/course")
      expect(response.body).to(include("data-intro-start-value=\"#{first.id}\""))
      expect(user.reload.intro_step).to(be_nil)
    end

    it "closes the chapter and marks it done once the last step is passed" do
      chapter = Intro::Map.chapter("taiwan")
      post("/intro/chapter/taiwan")
      chapter.length.times { post("/intro/next") }

      expect(user.reload.intro).to(be_chapter_done("taiwan"))
      expect(response).to(redirect_to(guide_path))

      get(guide_path)
      expect(response.body).not_to(include("intro-tour"))
    end

    it "starts the next chapter at its own first step" do
      post("/intro/chapter/taiwan")
      post("/intro/next")
      post("/intro/chapter/cards")

      first = Intro::Map.chapter("cards").steps.first
      get(guide_path)

      expect(response.body).to(include("data-intro-start-value=\"#{first.id}\""))
    end

    it "ignores a chapter that does not exist" do
      post("/intro/chapter/nonsense")

      expect(response).to(redirect_to(guide_path))
    end

    it "never blocks the app while a chapter is running" do
      post("/intro/chapter/taiwan")
      get("/progress")

      expect(response).to(have_http_status(:ok))
    end
  end
end
