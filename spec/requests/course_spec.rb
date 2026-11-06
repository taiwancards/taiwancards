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

  it "tags the lesson text with its own grammar points" do
    tagged = Huayu::CourseLessons.lessons.find { |entry| entry.lines.any? { |line| line.grammar.any? } }

    get("/course/#{tagged.slug}")

    expect(response.body).to(include("data-layer=\"grammar\""))
    expect(Nokogiri::HTML(response.body).css(".layer-grammar a").map { |link| link["href"] }).to(
      include("/en/grammar/#{tagged.lines.flat_map(&:grammar).first}")
    )
  end

  it "keeps an explanation hidden behind every task it can explain" do
    get("/course/#{lesson.slug}")

    notes = Nokogiri::HTML(response.body).css("[data-course-task-target='note']")
    expect(notes).not_to(be_empty)
    expect(notes).to(all(satisfy { |note| note.key?("hidden") }))
  end

  it "shows the Russian side on the Russian page" do
    read_in("ru")
    get("/ru/course/#{lesson.slug}")

    expect(response.body).to(include(lesson.goal_for(:ru)))
    expect(response.body).not_to(include(lesson.goal_for(:en)))
  end

  it "shows the Vietnamese side, line by line, on the Vietnamese page" do
    read_in("vi")
    get("/vi/course/#{lesson.slug}")

    expect(response.body).to(include(lesson.goal_for(:vi), CGI.escapeHTML(lesson.lines.first.translation(:vi))))
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
    expect(Nokogiri::HTML(response.body).css("[data-controller~='course-quiz']")).not_to(be_empty)
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

  it "lets the reply tasks be answered aloud before the options open" do
    with_reply = Huayu::CourseLessons.lessons.find { |entry| entry.exercises.any? { |task| task.kind == "reply" } }

    get("/course/#{with_reply.slug}")

    page = Nokogiri::HTML(response.body)
    replies = with_reply.exercises.count { |task| task.kind == "reply" }
    expect(page.css("[data-layer='aloud']").size).to(eq(1))
    expect(page.css(".aloud-gate [data-action='course-task#reveal']").size).to(eq(replies))
    expect(page.css(".aloud-options").size).to(eq(replies))
  end

  it "explains how a character the lesson brings in is built" do
    char = lesson.words.join[/\p{Han}/]
    create(
      :lexeme,
      kind: :character,
      text: char,
      data: {"etymology" => {"type" => "ideographic", "hint" => "two parts"}}
    )

    get("/course/#{lesson.slug}")

    expect(response.body).to(include(I18n.t("course.characters"), "two parts"))
  end

  it "opens with the line the learner will be able to say after it" do
    get("/course/#{lesson.slug}")

    expect(response.body).to(include(lesson.key_line.zh, CGI.escapeHTML(lesson.key_line.translation(:en))))
  end

  context("for a visitor with no account", :no_auth) do
    let(:stage) { Huayu::CourseLessons.stages.first }

    it "lets the shelf, a lesson and a level test be read without a session" do
      ["/course", "/course/#{lesson.slug}", "/course/exam/#{stage.slug}"].each do |path|
        get(path)

        expect(response).to(have_http_status(:ok), path)
        expect(response.headers["Cache-Control"]).to(include("public"), path)
        expect(response.headers["Set-Cookie"].to_s).not_to(include("_taiwancards_session"), path)
      end
    end

    it "lets the tasks be done in the page and asks for a sign-in only to keep the score" do
      get("/course/#{lesson.slug}")

      page = Nokogiri::HTML(response.body)
      expect(page.css("[data-controller='course-task']")).not_to(be_empty)
      expect(page.css("form[action$='/done']")).to(be_empty)
      expect(page.css("form[action$='/deck']")).to(be_empty)
      expect(page.css("a[href$='/login']").map(&:text)).to(include(I18n.t("course.sign_in")))
      expect(page.at_css("[data-controller~='analyzer']")["data-analyzer-activate-url-value"]).to(be_blank)
    end

    it "counts the lessons of a stage instead of showing a progress bar" do
      get("/course")

      expect(response.body).to(
        include(I18n.t("course.stage_lessons", count: Huayu::CourseLessons.by_stage[stage.slug].size))
      )
      expect(response.body).not_to(include(I18n.t("course.resume")))
    end

    it "keeps the progress page and every write behind the login" do
      get("/course/progress")
      expect(response).to(redirect_to(login_path))

      post("/course/#{lesson.slug}/done", params: {score: 3})
      expect(response).to(redirect_to(login_path))
      expect(CourseCompletion.count).to(eq(0))
    end
  end

  it "records a finished level test under its stage, capped at the number of questions" do
    stage = Huayu::CourseLessons.stages.first

    post("/course/exam/#{stage.slug}", params: {score: 9_999})

    completion = CourseCompletion.find_by(user: current_user, slug: "exam:#{stage.slug}")
    expect(completion.score).to(eq(stage.exam.size))
    expect(completion.total).to(eq(stage.exam.size))
    expect(response).to(redirect_to(course_exam_path(stage)))
  end
end
