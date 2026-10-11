# frozen_string_literal: true

module Learn
  class NextStep
    Step = Data.define(:kind, :subject) do
      def initialize(kind:, subject: nil) = super
    end

    PHONETIC_STEPS = %w[zhuyin bridge drill typing].freeze

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def call
      case user.goal
      when "classes"
        classes_step
      when "tocfl"
        exam_step
      else
        guided_step
      end
    end

    private

    attr_reader :user

    def guided_step
      return starter_step if starter.active?

      phonetic = pending_phonetic_step
      return Step.new(kind: phonetic) if phonetic
      return Step.new(kind: "review") if due?

      lesson = next_lesson
      return Step.new(kind: "lesson", subject: lesson.slug) if lesson && !lesson_done_today?
      return Step.new(kind: "study") unless quota_reached?
      return Step.new(kind: "lesson", subject: lesson.slug) if lesson

      Step.new(kind: "graded")
    end

    def exam_step
      return starter_step if starter.active?
      return Step.new(kind: "study") if due? || !quota_reached?

      plan = StudyPlan.find_by(user:)
      Step.new(kind: "grammar", subject: plan && Huayu::CourseProgress::GRAMMAR_LEVELS[plan.target_level.downcase])
    end

    def classes_step
      return Step.new(kind: "decks") if due? || fresh_in_decks?

      deck = Collection.desks_for(user).recent.first
      return Step.new(kind: "practice", subject: deck.id) if deck&.items_count&.positive?

      Step.new(kind: "add_words")
    end

    def starter = @starter ||= Learn::Starter.new(user)

    def starter_step
      return Step.new(kind: "review") if due?

      Step.new(kind: "starter", subject: starter.next_lesson.slug)
    end

    def pending_phonetic_step
      return nil if user.level_grade.positive?

      step = Onboarding::Path.new(user).steps.find { |item|
        PHONETIC_STEPS.include?(item[:key]) && item[:state] != :done
      }
      step && step[:key]
    end

    def due?
      return @due if defined?(@due)

      @due = Study::TodayDesk.new(user, now: @now).summary[:due].positive?
    end

    def quota_reached? = Study::DailyLoad.new(user, now: @now).reached?

    def next_lesson
      done = CourseCompletion.owned_by(user).pluck(:slug).to_set
      Huayu::CourseLessons.lessons.find { |lesson| done.exclude?(lesson.slug) }
    end

    def lesson_done_today?
      CourseCompletion.owned_by(user).where(completed_at: @now.beginning_of_day..).exists?
    end

    def fresh_in_decks?
      studied = LexemeMemory.active.owned_by(user).where.not(state: :unseen).select(:lexeme_id)
      CollectionItem
        .joins(:collection)
        .merge(Collection.desks_for(user))
        .where
        .not(lexeme_id: studied)
        .exists?
    end
  end
end
