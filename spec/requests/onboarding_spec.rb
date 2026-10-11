# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding" do
  it "asks for the mode and the starting point on one screen" do
    sign_in(create(:user, :undecided))

    get("/start")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("onboarding.goal_question"), I18n.t("onboarding.level_question.tocfl")))
    expect(response.body).not_to(include("id=\"goal-picker\""))
  end

  it "stores both answers and sends a complete beginner home" do
    user = sign_in(create(:user, :undecided))

    post("/start", params: {goal: "guided", level: "zero", known: "zero"})

    expect(response).to(redirect_to("/en/desk"))
    expect(user.reload).to(have_attributes(goal: "guided", start_level: "zero"))
  end

  it "sends someone unsure of their level to the placement test" do
    user = sign_in(create(:user, :undecided))

    post("/start", params: {goal: "tocfl", level: "unknown"})

    expect(response).to(redirect_to("/en/placement"))
    expect(user.reload.start_level).to(eq("characters"))
  end

  it "takes a stated level as the level already reached and counts what lies below it as known" do
    user = sign_in(create(:user, :undecided))
    below = create(:lexeme, kind: :word, text: "學校", data: {"tbcl_grade" => 2, "freq_rank" => 900})
    above = create(:lexeme, kind: :word, text: "研究", data: {"tbcl_grade" => 4, "freq_rank" => 900})

    post("/start", params: {goal: "guided", level: "3"})

    expect(response).to(redirect_to("/en/desk"))
    expect(user.reload).to(have_attributes(level: "3", start_level: "experienced"))
    expect(user.path_steps_done).to(include("placement"))
    expect(LexemeMemory.owned_by(user).where(lexeme: below)).to(exist)
    expect(LexemeMemory.owned_by(user).where(lexeme: above)).to(be_empty)
  end

  it "asks a beginner what is familiar, down to zhuyin" do
    user = sign_in(create(:user, :undecided))

    post("/start", params: {goal: "tocfl", level: "zero", known: "zhuyin"})

    expect(user.reload).to(have_attributes(level: "zero", start_level: "zhuyin"))
    expect(Onboarding::Path.new(user).track).to(eq("zhuyin"))
  end

  it "keeps the level optional and informational for own courses" do
    user = sign_in(create(:user, :undecided))
    below = create(:lexeme, kind: :word, text: "學校", data: {"tbcl_grade" => 1, "freq_rank" => 900})

    post("/start", params: {goal: "classes"})
    expect(user.reload).to(have_attributes(goal: "classes", start_level: nil))

    user.update!(goal: nil)
    post("/start", params: {goal: "classes", level: "2"})
    expect(user.reload.level).to(eq("2"))
    expect(LexemeMemory.owned_by(user).where(lexeme: below)).to(be_empty)
  end

  it "requires a level for the exam and our method" do
    user = sign_in(create(:user, :undecided))

    post("/start", params: {goal: "guided"})
    expect(response).to(redirect_to("/en/start"))

    post("/start", params: {goal: "guided", level: "wizard"})

    expect(response).to(redirect_to("/en/start"))
    expect(user.reload.start_level).to(be_nil)
  end

  it "leaves an existing learner's level, cards and schedule exactly as they were" do
    user = sign_in(create(:user, :undecided, prefs: {"level" => "3"}))
    word = create(:lexeme, kind: :word, text: "學校", data: {"tbcl_grade" => 2})
    memory = LexemeMemory.create!(
      user:,
      lexeme: word,
      facet: :recognition,
      state: :review,
      stability: 30,
      difficulty: 6,
      reps: 7,
      due_at: 3.days.from_now,
      last_reviewed_at: 1.day.ago
    )
    before = memory.attributes.except("updated_at")

    post("/start", params: {goal: "classes", level: "zero", known: "phonetics"})

    expect(user.reload).to(have_attributes(level: "3", goal: "classes", start_level: "phonetics"))
    expect(memory.reload.attributes.except("updated_at")).to(eq(before))
    expect(LexemeMemory.owned_by(user).count).to(eq(1))
  end

  it "asks only for the mode once the starting point is known" do
    user = sign_in(create(:user, :undecided, prefs: {"start_level" => "zero"}))

    get("/dict")
    expect(response.body).to(include("id=\"goal-picker\""))
    expect(response.body).not_to(include(I18n.t("onboarding.level_question.tocfl")))

    post("/start", params: {goal: "classes"}, headers: {"HTTP_REFERER" => "http://www.example.com/en/dict"})

    expect(response).to(redirect_to("/en/dict"))
    expect(user.reload.goal).to(eq("classes"))
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
    switching = Onboarding::Path::TRACKS.fetch("phonetics")

    expect(zero).to(include("zhuyin", "tones"))
    expect(switching).to(include("bridge"))
    expect(switching).not_to(include("zhuyin", "tones_theory"))
    expect(zero).not_to(eq(switching))
  end

  it "sends someone who already reads zhuyin and characters straight to the placement test" do
    track = Onboarding::Path::TRACKS.fetch("characters")

    expect(track.first).to(eq("placement"))
    expect(track).to(include("readings"))
    expect(track).not_to(include("bridge"))
  end

  it "puts the course on every track, whatever the starting point" do
    Onboarding::Path::TRACKS.each_value do |track|
      expect(track).to(include("course"))
    end
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

  it "keeps START on the first-steps track until a beginner finishes it" do
    expect(desk_start_path).to(eq(starter_lesson_path(Huayu::StarterTrack.lessons.first)))

    Huayu::StarterTrack.lessons.each do |lesson|
      CourseCompletion.record(
        user: @authenticated_user,
        slug: "#{Learn::Starter::PREFIX}#{lesson.slug}",
        score: 1,
        total: 1
      )
    end

    Onboarding::Path::STEPS.each_key { |key| @authenticated_user.mark_path_step!(key) }

    expect(desk_start_path).to(eq(study_path(mode: "today")))
  end

  it "offers a way back to the roadmap from a step page" do
    get(practice_typing_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("onboarding.path.back"))))
    expect(response.body).to(include(roadmap_path))
  end
end
