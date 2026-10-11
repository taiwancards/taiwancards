# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Start dispatch" do
  def finish_track!
    Huayu::StarterTrack.lessons.each do |lesson|
      CourseCompletion.record(
        user: @authenticated_user,
        slug: "#{Learn::Starter::PREFIX}#{lesson.slug}",
        score: 1,
        total: 1
      )
    end
  end

  it "sends a complete beginner to the first lesson of the first-steps track" do
    expect(desk_start_path).to(eq(starter_lesson_path(Huayu::StarterTrack.lessons.first)))
  end

  it "keeps a beginner on the track while lessons remain" do
    first, second = Huayu::StarterTrack.lessons.first(2)
    CourseCompletion.record(
      user: @authenticated_user,
      slug: "#{Learn::Starter::PREFIX}#{first.slug}",
      score: 1,
      total: 1
    )

    expect(desk_start_path).to(eq(starter_lesson_path(second)))
  end

  it "goes to cards once the track and the roadmap are behind the beginner" do
    finish_track!
    Onboarding::Path.new(@authenticated_user).steps.each { |step| @authenticated_user.mark_path_step!(step[:key]) }

    expect(desk_start_path).to(eq(study_path(mode: "today")))
  end

  it "sends someone with a level straight to cards, skipping phonetics" do
    @authenticated_user.update!(prefs: {"level" => "3"})

    expect(desk_start_path).to(eq(study_path(mode: "today")))
  end

  it "lets the profile override the level without a placement test" do
    patch("/profile", params: {user: {level: "5"}})

    expect(@authenticated_user.reload.level).to(eq("5"))
    expect(@authenticated_user.level_grade).to(eq(5))
  end

  it "rejects a level outside the known scale" do
    patch("/profile", params: {user: {level: "99"}})

    expect(@authenticated_user.reload.level).to(eq("zero"))
  end

  it "puts someone switching from pinyin on the same track" do
    @authenticated_user.update!(prefs: {"goal" => "guided", "level" => "phonetics"})

    expect(desk_start_path).to(eq(starter_lesson_path(Huayu::StarterTrack.lessons.first)))
  end
end
