# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Placement test" do
  READER = {experience: "year", script: "zhuyin", characters: "read", variety: "taiwan"}.freeze
  BEGINNER = {experience: "none", script: "none", characters: "none", variety: "none"}.freeze

  before do
    12.times do |i|
      create(
        :lexeme,
        kind: :word,
        text: "詞彙#{i}",
        meanings: {"en" => "meaning #{i}"},
        data: {"tbcl_grade" => 2, "freq_rank" => i + 1}
      )
    end
  end

  def current_test
    PlacementTest.where(user: @authenticated_user).order(:created_at).last
  end

  def start(intake = READER, **rest)
    post("/placement", params: {intake:, **rest})
  end

  it "shows the intake form before the test is started" do
    get("/placement")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("placement.intake.experience.question")))
  end

  it "starts a test and serves the first question" do
    start

    expect(current_test).to(be_status_in_progress)
    expect(current_test.pending["choices"].size).to(eq(4))
    expect(current_test.pending["axis"]).to(be_present)

    get("/placement")
    expect(response.body).to(include(current_test.pending["prompt"]))
  end

  it "records the axis and difficulty of every answer" do
    start
    first = current_test.pending

    post("/placement/answer", params: {choice: first["answer"]})

    row = current_test.reload.asked.first
    expect(row["correct"]).to(be(true))
    expect(row["axis"]).to(eq(first["axis"]))
    expect(row["difficulty"]).to(be_a(Numeric))
  end

  it "treats a skipped question as wrong rather than crashing" do
    start
    post("/placement/answer", params: {choice: ""})

    expect(current_test.reload.asked.first["correct"]).to(be(false))
  end

  it "gives an absolute beginner a three-item sanity check, not a full test" do
    start(BEGINNER)

    intake = current_test.intake_result
    expect(intake).to(be_sanity)
    expect(intake.budget).to(eq(Placement::Intake::SANITY_BUDGET))
  end

  it "asks a learner who reads no characters nothing about reading" do
    start(BEGINNER.merge(experience: "some", script: "pinyin"))

    axes = Array(current_test.intake_result.axes)
    expect(axes).to(include("listening", "tones", "syllables"))
    expect(axes).not_to(include("characters", "sentences", "vocab_size"))
  end

  it "reaches a result and can apply it, seeding memories" do
    start

    30.times do
      break unless current_test.reload.status_in_progress?

      item = current_test.pending
      break if item.blank?

      post("/placement/answer", params: {choice: (item["answer"].to_i + 1) % 4})
    end

    expect(current_test.reload).to(be_status_finished)

    get("/placement")
    expect(response.body).to(include(I18n.t("placement.apply")))

    post("/placement/apply", params: {grade: 2})

    expect(current_test.reload).to(be_status_applied)
    expect(LexemeMemory.owned_by(@authenticated_user).state_review.count).to(be > 0)
  end

  it "stores a per-axis profile with the result" do
    start

    30.times do
      break unless current_test.reload.status_in_progress?
      break if current_test.pending.blank?

      post("/placement/answer", params: {choice: current_test.pending["answer"]})
    end

    profile = current_test.reload.profile
    expect(profile["axes"]).to(be_present)
    expect(profile["tolerance"]).to(be_in(Placement::Ability::TOLERANCES))
  end

  it "warns a China-variant learner that nothing here is simplified" do
    start(READER.merge(variety: "china"))
    current_test.update!(status: :finished, result_grade: 2, pending: {}, profile: {"axes" => {}, "position" => 0.0})

    get("/placement")

    expect(response.body).to(include(I18n.t("placement.china.title")))
  end

  it "does not seed twice when applied again" do
    start
    current_test.update!(status: :finished, result_grade: 2, pending: {})
    post("/placement/apply", params: {grade: 2})
    seeded = LexemeMemory.owned_by(@authenticated_user).count

    post("/placement/apply", params: {grade: 2})

    expect(LexemeMemory.owned_by(@authenticated_user).count).to(eq(seeded))
  end
end
