# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Study goals" do
  it "asks an undecided learner to pick a mode before anything else, on any page" do
    sign_in(create(:user, :undecided))

    %w[/desk /dict].each do |path|
      get(path)

      expect(response.body).to(include("id=\"goal-picker\"", "aria-modal=\"true\""))
      User::GOALS.each { |goal| expect(response.body).to(include("value=\"#{goal}\"")) }
      expect(response.body).not_to(include("id=\"intro-tour\""))
    end
  end

  it "lets a newcomer switch the interface language right inside the picker" do
    sign_in(create(:user, :undecided))

    get("/en/desk")
    picker = response.body[/id="goal-picker".*/m]

    expect(picker).to(include("action=\"/locale/ru\"", "Русский"))
  end

  it "leaves a learner who has chosen alone" do
    get("/desk")

    expect(response.body).not_to(include("id=\"goal-picker\""))
  end

  it "stores the choice and returns to the page it was made on" do
    user = sign_in(create(:user, :undecided))

    patch("/goal", params: {goal: "classes"}, headers: {"Referer" => "http://www.example.com/en/dict"})

    expect(user.reload.goal).to(eq("classes"))
    expect(response).to(redirect_to("/en/dict"))
  end

  it "ignores a mode it does not know" do
    user = sign_in(create(:user, :undecided))

    patch("/goal", params: {goal: "everything"})

    expect(user.reload.goal).to(be_nil)
  end

  it "survives a progress reset" do
    user = sign_in(create(:user, prefs: {"goal" => "tocfl"}))

    delete("/profile/reset")

    expect(user.reload.goal).to(eq("tocfl"))
  end

  it "can be changed from the profile" do
    get("/profile")

    expect(response.body).to(include("id=\"goal\""))
    User::GOALS.each { |goal| expect(response.body).to(include("value=\"#{goal}\"")) }
  end

  it "puts the exam tools first in the study menu for an exam candidate" do
    sign_in(create(:user, prefs: {"goal" => "tocfl"}))

    get("/menu")

    expect(response.body.index("href=\"#{mock_exams_path}\"")).to(be < response.body.index("href=\"#{course_path}\""))
  end

  it "puts the course first for a guided learner and the decks first for a class-goer" do
    sign_in(create(:user, prefs: {"goal" => "guided"}))
    get("/menu")
    guided = response.body

    sign_in(create(:user, prefs: {"goal" => "classes"}))
    get("/menu")
    classes = response.body

    course = "href=\"#{course_path}\""
    decks = "href=\"#{desks_path}\""
    expect(guided.index(course)).to(be < guided.index(decks))
    expect(classes.index(decks)).to(be < classes.index(course))
  end

  it "marks what the mode recommends without hiding anything" do
    sign_in(create(:user, prefs: {"goal" => "tocfl"}))

    get("/menu")

    expect(response.body.scan("for you").size).to(be >= 3)
    expect(response.body).to(include("href=\"#{characters_path}\""))
  end
end
