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

      expect(response).to(redirect_to("/en/desk"))
    end
  end

  describe "while the tour is running" do
    it "renders the tour" do
      stand_on("welcome")
      get("/desk")

      expect(response.body).to(include("intro-tour"))
    end

    it "sends the reader back to the step they wandered off" do
      stand_on("search")
      get("/progress")

      expect(response).to(redirect_to("/en/menu"))
    end

    it "allows the page the step sits on" do
      stand_on("search")
      get("/menu")

      expect(response).to(have_http_status(:ok))
    end

    it "hides the setup strip it would otherwise nag with" do
      stand_on("welcome")
      get("/desk")

      expect(response.body).not_to(include(I18n.t("intro.setup.tour")))
    end

    it "can be put off, and asks again from the strip" do
      stand_on("search")
      delete("/intro")

      expect(user.reload.intro).to(be_pending)
      get("/progress")
      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include(I18n.t("intro.setup.tour")))
    end

    it "resumes on the step it was left on" do
      stand_on("display")
      delete("/intro")
      post("/intro/start")

      expect(step_id).to(eq("display"))
    end

    it "falls back to the first step when the stored id is gone from the map" do
      stand_on("a-step-we-deleted")

      expect(user.intro.step.id).to(eq(Intro::Map.essential.first.id))
    end
  end

  describe "moving through the tour" do
    it "advances and remembers" do
      first, second = Intro::Map.essential.first(2)
      stand_on(first.id)
      post("/intro/next")

      expect(step_id).to(eq(second.id))
    end

    it "goes back" do
      first, second = Intro::Map.essential.first(2)
      stand_on(second.id)
      post("/intro/back")

      expect(step_id).to(eq(first.id))
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

    it "hands the reader over to the guide when it ends, wherever it was started from" do
      stand_on(Intro::Map.essential.last.id)
      get("/dict")
      post("/intro/start", headers: {"HTTP_REFERER" => "http://www.example.com/dict"})
      post("/intro/next")

      expect(response).to(redirect_to("/en/help"))
    end

    it "no longer asks which language to read in" do
      expect(Intro::Map.essential.map(&:id)).not_to(include("language"))
      expect(Rails.application.routes.url_helpers).not_to(respond_to(:intro_language_path))
    end

    it "leaves the reader on the guide when the tour ends" do
      expect(Intro::Map.essential.last.path).to(eq("/help"))
    end
  end

  describe "the escape hatch" do
    it "lets everyone through when the gate is switched off" do
      stand_on("search")
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
