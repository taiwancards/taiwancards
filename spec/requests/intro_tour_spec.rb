# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Intro tour" do
  let(:user) { @authenticated_user }

  describe "the essential tour" do
    before { user.update!(prefs: user.prefs.merge("intro_stage" => "running", "intro_step" => "search")) }

    it "renders for a user who is walking it" do
      get("/desk")

      expect(response.body).to(include("intro-tour"))
    end

    it "anchors its step to an element that exists on the page" do
      get("/desk")

      expect(response.body).to(include("data-tour=\"search\""))
      expect(response.body).to(include("data-intro-start-value=\"search\""))
    end

    it "offers no way to skip a step, only to put the whole tour off" do
      get("/desk")

      expect(response.body).not_to(include(I18n.t("intro.skip")))
      expect(response.body).to(include(I18n.t("intro.later")))
    end
  end

  describe "a fresh account" do
    it "is never handed the release notes it could not have missed" do
      expect(user.intro.unseen).to(be_empty)

      get("/desk")

      expect(response.body).not_to(include(CGI.escapeHTML(I18n.t("intro.label_whats_new"))))
    end

    it "is offered the tour rather than pushed through it" do
      expect(user.intro).to(be_pending)
      expect(user.intro).not_to(be_required)
    end
  end

  describe "what is new" do
    before do
      user.intro.finish!
      user.update!(prefs: user.prefs.merge("intro_version" => 0))
    end

    it "greets a finished user with the release notes instead of the tour" do
      get("/desk")

      expect(response.body).to(include(CGI.escapeHTML(I18n.t("intro.label_whats_new"))))
    end

    it "can be dismissed" do
      get("/desk")

      expect(response.body).to(include(I18n.t("intro.skip")))
    end

    it "announces a release only once" do
      post("/intro/seen")
      get("/desk")

      expect(response.body).not_to(include("intro-tour"))
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

    it "keeps the reader where they are and walks them from there" do
      post("/intro/chapter/taiwan")

      expect(response).to(redirect_to(guide_path))
    end

    it "hands the whole chapter to the page, so a dropdown can stay open between steps" do
      post("/intro/chapter/taiwan")
      get(guide_path)

      chapter = Intro::Map.chapter("taiwan")
      payload = response.body[/data-intro-steps-value="([^"]*)"/, 1]
      steps = JSON.parse(CGI.unescapeHTML(payload.to_s))

      expect(steps.map { |step| step["id"] }).to(eq(chapter.steps.map(&:id)))
      expect(steps.map { |step| step["action"] }).to(include("click"))
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
      post("/intro/chapter/taiwan")
      post("/intro/next")
      post("/intro/back")

      first = Intro::Map.chapter("taiwan").steps.first
      get(guide_path)
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
