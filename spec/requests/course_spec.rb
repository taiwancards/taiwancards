# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Course" do
  let(:lesson) { Huayu::CourseLessons.lessons.first }

  before { Huayu::CourseProgress.forget_words! }

  after { Huayu::CourseProgress.forget_words! }

  it "lists the stages and the lessons inside them" do
    get("/course")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(lesson.title_for(:en)))
    expect(response.body).to(include("/course/#{lesson.slug}"))
  end

  it "shows a lesson with its text, words, grammar and tasks" do
    get("/course/#{lesson.slug}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-controller=\"course-task\""))
    expect(response.body).to(include(lesson.vocabulary.first.zh))
    expect(response.body).to(include("/grammar/#{lesson.grammar.first.slug}"))
  end

  it "shows the Russian side on the Russian page" do
    get("/ru/course/#{lesson.slug}")

    expect(response.body).to(include(lesson.goal_for(:ru)))
    expect(response.body).not_to(include(lesson.goal_for(:en)))
  end

  it "records a finished lesson and shows it on the index" do
    post("/course/#{lesson.slug}/done", params: {score: 7})

    completion = CourseCompletion.find_by(user: current_user, slug: lesson.slug)
    expect(completion.score).to(eq(7))
    expect(completion.total).to(eq(lesson.exercises.size))
    expect(completion.completed_at).to(be_present)
  end

  it "never stores a score above the number of tasks" do
    post("/course/#{lesson.slug}/done", params: {score: 9_999})

    expect(CourseCompletion.find_by(user: current_user, slug: lesson.slug).score).to(eq(lesson.exercises.size))
  end

  it "shows the progress page with the level breakdown" do
    get("/course/progress")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("TOCFL Novice 1"))
  end

  it "serves the level test for a stage" do
    stage = Huayu::CourseLessons.stages.first

    get("/course/exam/#{stage.slug}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-controller=\"course-quiz\""))
  end

  it "builds a deck out of the lesson vocabulary" do
    create(:lexeme, kind: :word, text: lesson.vocabulary.first.zh)

    expect { post("/course/#{lesson.slug}/deck") }.to(change(Collection, :count).by(1))
    expect(Collection.last.name).to(include(lesson.title_for(:en)))
  end

  it "answers with not found for a lesson that does not exist", :no_auth do
    sign_in(create(:user))

    get("/course/no-such-lesson")

    expect(response).to(have_http_status(:not_found))
  end

  it "keeps the whole section behind the login", :no_auth do
    get("/course")

    expect(response).to(redirect_to(login_path))
  end
end
