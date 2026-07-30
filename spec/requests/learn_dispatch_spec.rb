# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Start dispatch" do
  it "sends a complete beginner to the roadmap, not straight into a step" do
    expect(desk_start_path).to(eq(roadmap_path))
  end

  it "keeps a beginner on the roadmap while steps remain" do
    @authenticated_user.mark_path_step!("zhuyin")

    expect(desk_start_path).to(eq(roadmap_path))
  end

  it "goes to cards once the whole roadmap is behind the beginner" do
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

  it "still routes the phonetics level through the roadmap" do
    @authenticated_user.update!(prefs: {"level" => "phonetics"})

    expect(desk_start_path).to(eq(roadmap_path))
  end
end
