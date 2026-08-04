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
      expect(response.body).to(include("data-intro-anchor-value=\"search\""))
    end

    it "offers no way to skip a step, only to put the whole tour off" do
      get("/desk")

      expect(response.body).not_to(include(I18n.t("intro.skip")))
      expect(response.body).to(include(I18n.t("intro.later")))
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

    it "lists every chapter on the guide tab" do
      get("/profile/guide")

      Intro::Map.chapters.each do |chapter|
        expect(response.body).to(include(I18n.t("#{chapter.i18n_key}.title")))
      end
    end

    it "starts a chapter on the page its first step lives on" do
      chapter = Intro::Map.chapter("taiwan")
      post("/intro/chapter/taiwan")

      expect(response).to(redirect_to("/en#{chapter.steps.first.path}"))
    end

    it "runs the chapter and lets the user leave at any point" do
      post("/intro/chapter/taiwan")
      get("/everyday")

      expect(response.body).to(include("intro-tour"))
      expect(response.body).to(include(I18n.t("intro.skip")))
    end

    it "remembers a finished chapter" do
      post("/intro/chapter/taiwan")
      delete("/intro/chapter", params: {completed: "1"})

      expect(user.reload.intro).to(be_chapter_done("taiwan"))
    end

    it "moves forward one step at a time and lands on each step's own page" do
      chapter = Intro::Map.chapter("taiwan")
      post("/intro/chapter/taiwan")

      chapter.steps.each_cons(2) do |current, following|
        get(current.path)
        expect(response.body).to(include(I18n.t("#{current.i18n_key}.title")))

        post("/intro/next")
        expect(response).to(redirect_to("/en#{following.path}"))
      end
    end

    it "steps back inside the chapter instead of touching the mandatory tour" do
      chapter = Intro::Map.chapter("taiwan")
      post("/intro/chapter/taiwan")
      post("/intro/next")
      post("/intro/back")

      get(chapter.steps.first.path)
      expect(response.body).to(include(I18n.t("#{chapter.steps.first.i18n_key}.title")))
      expect(user.reload.intro_step).to(be_nil)
    end

    it "closes the chapter and marks it done once the last step is passed" do
      chapter = Intro::Map.chapter("taiwan")
      post("/intro/chapter/taiwan")
      chapter.length.times { post("/intro/next") }

      expect(user.reload.intro).to(be_chapter_done("taiwan"))
      expect(response).to(redirect_to(guide_path))

      get(chapter.steps.first.path)
      expect(response.body).not_to(include("intro-tour"))
    end

    it "starts the next chapter at its own first step" do
      post("/intro/chapter/taiwan")
      post("/intro/next")
      post("/intro/chapter/cards")

      first = Intro::Map.chapter("cards").steps.first
      get(first.path)

      expect(response.body).to(include(I18n.t("#{first.i18n_key}.title")))
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
