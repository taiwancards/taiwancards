# frozen_string_literal: true

module Learn
  class Home
    RECENT_DECKS = 5
    ACTIVITY_WEEKS = 12

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def layout = user.goal || "guided"

    def on_desk
      @on_desk ||= LexemeMemory.active.owned_by(user).joins(:lexeme).distinct.count(:lexeme_id)
    end

    def today = @today ||= Study::TodayDesk.new(user).summary

    def road = @road ||= Learn::Road.new(user)

    def plan = road.plan

    def target_level
      plan&.target_level || road.current&.level_tag || Learn::Road::LEVELS.first
    end

    def target_milestone
      road.milestones.find { |milestone| milestone.level_tag == target_level } || road.current
    end

    def mock_level
      level = target_level.to_s.downcase
      level if MockExam::Bank::LEVELS.map(&:downcase).include?(level)
    end

    def grammar_level = Huayu::CourseProgress::GRAMMAR_LEVELS[target_level.to_s.downcase]

    def decks = @decks ||= Collection.desks_for(user).recent.limit(RECENT_DECKS).to_a

    def decks_count = @decks_count ||= Collection.desks_for(user).count

    def course = @course ||= Huayu::CourseProgress.new(user)

    def resume_lesson
      return @resume_lesson if defined?(@resume_lesson)

      @resume_lesson = Huayu::CourseLessons.lessons.find { |lesson| course.completions[lesson.slug].nil? }
    end

    def resume_slice = resume_lesson && course.slice_for(resume_lesson.stage)

    def path = @path ||= Onboarding::Path.new(user)

    def starter = @starter ||= Learn::Starter.new(user)

    def starter_lesson = starter.active? ? starter.next_lesson : nil

    def path_step
      return nil if path.complete?

      path.steps.find { |step| step[:state] == :current }
    end

    def report = @report ||= StatsReport.new(user:)

    def streak = @streak ||= report.streak

    def activity = @activity ||= report.activity(weeks: ACTIVITY_WEEKS)
  end
end
