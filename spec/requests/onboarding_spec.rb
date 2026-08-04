# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding" do
  it "asks the starting question before anything is chosen" do
    get("/start")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("onboarding.question")))
    expect(response.body).to(include(I18n.t("onboarding.not_for.heading")))
  end

  it "sends a complete beginner to the roadmap" do
    post("/start", params: {start_level: "zero"})

    expect(response).to(redirect_to("/en/path"))
    expect(@authenticated_user.reload.start_level).to(eq("zero"))
  end

  it "sends someone with characters to the placement test" do
    post("/start", params: {start_level: "characters"})

    expect(response).to(redirect_to("/en/placement"))
  end

  it "rejects an unknown level" do
    post("/start", params: {start_level: "wizard"})

    expect(response).to(redirect_to("/en/start"))
    expect(@authenticated_user.reload.start_level).to(be_nil)
  end

  it "skips the question once a level is chosen" do
    @authenticated_user.update!(prefs: {"start_level" => "zero"})

    get("/start")

    expect(response).to(redirect_to("/en/path"))
  end

  it "still shows the question when asked again explicitly" do
    @authenticated_user.update!(prefs: {"start_level" => "zero"})

    get("/start", params: {again: 1})

    expect(response).to(have_http_status(:ok))
  end

  it "renders every step of the track the learner is on" do
    get("/path")

    expect(response).to(have_http_status(:ok))
    Onboarding::Path.new(@authenticated_user).steps.each do |step|
      expect(response.body).to(include(I18n.t("onboarding.path.steps.#{step[:key]}.title")))
    end
  end

  it "gives an absolute beginner a different track from someone switching off pinyin" do
    zero = Onboarding::Path::TRACKS.fetch("zero")
    switching = Onboarding::Path::TRACKS.fetch("characters")

    expect(zero).to(include("zhuyin", "tones"))
    expect(switching).to(include("bridge", "readings"))
    expect(zero).not_to(eq(switching))
  end

  it "puts the placement test first for an experienced learner" do
    expect(Onboarding::Path::TRACKS.fetch("experienced").first).to(eq("placement"))
  end

  it "marks and unmarks a step by hand" do
    @authenticated_user.update!(prefs: {"start_level" => "zero"})
    post("/path/step", params: {step: "zhuyin"})
    expect(@authenticated_user.reload.path_steps_done).to(include("zhuyin"))

    post("/path/step", params: {step: "zhuyin", undo: "1"})
    expect(@authenticated_user.reload.path_steps_done).not_to(include("zhuyin"))
  end

  it "ignores an unknown step" do
    post("/path/step", params: {step: "nonsense"})

    expect(response).to(redirect_to("/en/path"))
    expect(@authenticated_user.reload.path_steps_done).to(be_empty)
  end

  it "hides the pinyin step for someone who already knows pinyin" do
    @authenticated_user.update!(prefs: {"start_level" => "phonetics"})

    get("/path")

    expect(response.body).not_to(include(I18n.t("onboarding.path.steps.pinyin.title")))
  end

  it "never offers zhuyin from scratch to a learner who is only switching notation" do
    expect(Onboarding::Path::TRACKS.fetch("characters")).not_to(include("zhuyin"))
  end

  it "records a typing run and ticks the step off" do
    post("/practice/typing")

    expect(response).to(have_http_status(:no_content))
    expect(@authenticated_user.reload.practice_runs["typing"]).to(eq(1))
    expect(Onboarding::Path.new(@authenticated_user).steps.find { |s| s[:key] == "typing" }[:state]).to(eq(:done))
  end

  it "points every step at a route that exists" do
    Onboarding::Path::STEPS.each_value do |step|
      expect(Rails.application.routes.url_helpers).to(respond_to(step.route))
    end
  end

  it "sends each step to the page that can complete it" do
    @authenticated_user.update!(prefs: {"start_level" => "zero"})

    get("/path")

    expect(response.body).to(include(zhuyin_training_path))
    expect(response.body).to(include(practice_drill_path))
    expect(response.body).to(include(tones_drill_path))
    expect(response.body).to(include(phrases_path))
  end

  it "completes the tone step from the tone drill" do
    @authenticated_user.update!(prefs: {"start_level" => "zero"})

    expect { get(tones_drill_path) }
      .to(
        change { Onboarding::Path.new(@authenticated_user.reload).steps.find { |s| s[:key] == "tones" }[:state] }
          .from(:todo)
          .to(:done)
      )
  end

  it "hands the finished roadmap over to the home screen" do
    Onboarding::Path::STEPS.each_key { |key| @authenticated_user.mark_path_step!(key) }

    get("/path")

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("onboarding.path.done_cta"))))
    expect(response.body).to(include(desk_path))
  end

  it "keeps START pointed at the roadmap until a beginner finishes it" do
    expect(desk_start_path).to(eq(roadmap_path))

    Onboarding::Path::STEPS.each_key { |key| @authenticated_user.mark_path_step!(key) }

    expect(desk_start_path).to(eq(study_path(mode: "today")))
  end

  it "offers a way back to the roadmap from a step page" do
    get(practice_typing_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("onboarding.path.back"))))
    expect(response.body).to(include(roadmap_path))
  end
end
