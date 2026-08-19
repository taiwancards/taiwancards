# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The intro tour" do
  let(:user) { @authenticated_user }

  def step_id = user.reload.intro_step

  def stand_on(id)
    user.update!(prefs: user.prefs.merge("intro_stage" => "running", "intro_step" => id))
  end

  describe "a brand new account" do
    it "is not held anywhere" do
      get("/progress")

      expect(response).to(have_http_status(:ok))
    end

    it "is asked to take the tour instead of being pushed into it" do
      get("/desk")

      expect(response.body).to(include(I18n.t("intro.setup.tour")))
      expect(response.body).not_to(include("intro-tour"))
    end

    it "starts on the first step once the person asks for it" do
      post("/intro/start")

      expect(user.reload.intro).to(be_required)
      expect(user.intro.step.id).to(eq(Intro::Map.essential.first.id))
    end

    it "opens on the desk, where the search and the sections it talks about live" do
      post("/intro/start", headers: {"HTTP_REFERER" => "http://www.example.com/dict"})

      expect(response).to(redirect_to("/en/intro"))
    end
  end

  describe "while the tour is running" do
    it "shows the introduction page instead of an overlay" do
      stand_on("overview")
      get("/intro")

      expect(response.body).not_to(include("intro-tour"))
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("intro.page.title"))))
    end

    it "sends the reader back to the step they wandered off" do
      stand_on("overview")
      get("/progress")

      expect(response).to(redirect_to("/en/intro"))
    end

    it "allows the page the step sits on" do
      stand_on("overview")
      get("/intro")

      expect(response).to(have_http_status(:ok))
    end

    it "hides the setup strip it would otherwise nag with" do
      stand_on("overview")
      get("/desk")

      expect(response.body).not_to(include(I18n.t("intro.setup.tour")))
    end

    it "can be put off, and asks again from the strip" do
      stand_on("overview")
      delete("/intro")

      expect(user.reload.intro).to(be_pending)
      get("/progress")
      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("intro.setup.tour")))
    end

    it "resumes where it was left off" do
      stand_on("overview")
      delete("/intro")
      post("/intro/start")

      expect(step_id).to(eq("overview"))
    end

    it "falls back to the first step when the stored id is gone from the map" do
      stand_on("a-step-we-deleted")

      expect(user.intro.step.id).to(eq(Intro::Map.essential.first.id))
    end
  end

  describe "moving through the tour" do
    it "finishes as soon as the one page is done" do
      stand_on(Intro::Map.essential.first.id)
      post("/intro/next")

      expect(user.reload).to(be_intro_done)
    end

    it "cannot go back past the first step" do
      stand_on(Intro::Map.essential.first.id)
      post("/intro/back")

      expect(step_id).to(eq(Intro::Map.essential.first.id))
    end

    it "opens the app once the last step is done" do
      stand_on(Intro::Map.essential.last.id)
      post("/intro/next")

      expect(user.reload).to(be_intro_done)
      get("/progress")
      expect(response).to(have_http_status(:ok))
    end

    it "sends a reader who has no level yet to choose one" do
      stand_on(Intro::Map.essential.last.id)
      post("/intro/next")

      expect(response).to(redirect_to("/en/start"))
    end

    it "no longer asks which language to read in" do
      expect(Intro::Map.essential.map(&:id)).not_to(include("language"))
      expect(Rails.application.routes.url_helpers).not_to(respond_to(:intro_language_path))
    end

    it "lives on a page of its own rather than borrowing another" do
      expect(Intro::Map.essential.map(&:path)).to(eq(["/intro"]))
    end
  end

  describe "the escape hatch" do
    it "lets everyone through when the gate is switched off" do
      stand_on("overview")
      allow(Intro).to(receive(:gated?).and_return(false))

      get("/progress")

      expect(response).to(have_http_status(:ok))
    end
  end

  describe "once the tour is finished" do
    before { user.intro.finish! }

    it "stops rendering the tour" do
      get("/desk")

      expect(response.body).not_to(include("intro-tour"))
    end

    it "stops asking for it" do
      get("/desk")

      expect(response.body).not_to(include(I18n.t("intro.setup.tour")))
    end
  end
end
