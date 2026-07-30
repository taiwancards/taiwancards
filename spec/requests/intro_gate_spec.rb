# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The intro gate" do
  let(:user) { @authenticated_user }

  def step_id = user.reload.intro_step

  def stand_on(id)
    user.update!(prefs: user.prefs.merge("intro_stage" => "pending", "intro_step" => id))
  end

  describe "a brand new account" do
    it "starts on the first step of the mandatory tour" do
      expect(user.intro).to(be_required)
      expect(user.intro.step.id).to(eq(Intro::Map.essential.first.id))
    end

    it "renders the tour and blocks dismissal" do
      stand_on("welcome")
      get("/desk")

      expect(response.body).to(include("intro-tour"))
      expect(response.body).not_to(include(I18n.t("intro.skip")))
    end
  end

  describe "reaching for a page the current step does not sit on" do
    it "sends the user back to the step" do
      stand_on("search")
      get("/progress")

      expect(response).to(redirect_to("/desk"))
    end

    it "allows the page the step sits on" do
      stand_on("search")
      get("/desk")

      expect(response).to(have_http_status(:ok))
    end

    it "never redirects a step whose page has no path" do
      stand_on("language")
      get("/progress")

      expect(response).to(have_http_status(:ok))
    end
  end

  describe "resuming" do
    it "picks up on the stored step after the browser was closed" do
      stand_on("display")
      reset!
      sign_in(user)
      get("/desk")

      expect(response).to(have_http_status(:ok))
      expect(step_id).to(eq("display"))
    end

    it "falls back to the first step when the stored id is gone from the map" do
      stand_on("a-step-we-deleted")

      expect(user.intro.step.id).to(eq(Intro::Map.essential.first.id))
    end
  end

  describe "moving through the tour" do
    it "advances and remembers" do
      stand_on("search")
      post("/intro/next")

      expect(step_id).to(eq("sections"))
    end

    it "goes back" do
      stand_on("sections")
      post("/intro/back")

      expect(step_id).to(eq("search"))
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
  end

  describe "the language step" do
    it "applies the choice and moves on" do
      stand_on("language")
      post("/intro/language/ru")

      expect(user.reload.locale).to(eq("ru"))
      expect(step_id).not_to(eq("language"))
    end
  end

  describe "an administrator" do
    before { user.update!(admin: true) }

    it "walks the same mandatory tour as everybody else" do
      stand_on("search")
      get("/progress")

      expect(response).to(redirect_to("/desk"))
    end

    it "cannot reach the admin pages before finishing it" do
      stand_on("search")
      get("/admin/users")

      expect(response).to(redirect_to("/desk"))
    end

    it "is offered no way to skip" do
      get("/desk")

      expect(response.body).not_to(include(I18n.t("intro.skip")))
    end
  end

  describe "a fresh account" do
    it "needs the tour no matter how it was created" do
      expect(User.new.intro).to(be_required)
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

    it "stops gating" do
      get("/progress")

      expect(response).to(have_http_status(:ok))
    end

    it "stops rendering the mandatory tour" do
      get("/desk")

      expect(response.body).not_to(include("intro-tour"))
    end
  end
end
