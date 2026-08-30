# frozen_string_literal: true

module Onboarding
  class Path
    FIRST_CARDS_TARGET = 20

    Step = Data.define(:key, :auto, :optional, :link, :kind) do
      def optional? = optional

      def theory? = kind == :theory

      def route = :"#{link}_path"
    end

    STEPS = [
      Step.new(key: "zhuyin_theory", auto: :zhuyin_theory, optional: false, link: :practice_zhuyin, kind: :theory),
      Step.new(key: "zhuyin", auto: :zhuyin_trainer, optional: false, link: :zhuyin_training, kind: :practice),
      Step.new(key: "drill", auto: :drill, optional: false, link: :practice_drill, kind: :practice),
      Step.new(key: "tones_theory", auto: :tones_theory, optional: false, link: :tones, kind: :theory),
      Step.new(key: "tones", auto: :tones, optional: false, link: :tones_drill, kind: :practice),
      Step.new(key: "phrases", auto: :phrases, optional: false, link: :phrases, kind: :practice),
      Step.new(key: "bridge", auto: :zhuyin_trainer, optional: false, link: :zhuyin_training, kind: :practice),
      Step.new(key: "readings", auto: nil, optional: true, link: :variants, kind: :theory),
      Step.new(key: "typing", auto: :typing, optional: false, link: :practice_typing, kind: :practice),
      Step.new(key: "hanzi", auto: :hanzi_theory, optional: false, link: :hanzi, kind: :theory),
      Step.new(key: "course", auto: :course, optional: false, link: :course, kind: :practice),
      Step.new(key: "placement", auto: :placement, optional: false, link: :placement, kind: :practice),
      Step.new(key: "first_cards", auto: :reviews, optional: false, link: :study, kind: :practice),
      Step.new(key: "plan", auto: nil, optional: true, link: :study_plan, kind: :practice)
    ]
      .index_by(&:key)
      .freeze

    TRACKS = {
      "zero" => %w[zhuyin_theory zhuyin drill tones_theory tones typing hanzi phrases course first_cards plan],
      "phonetics" => %w[zhuyin_theory bridge drill typing hanzi phrases course first_cards plan],
      "characters" => %w[placement readings phrases course first_cards plan],
      "experienced" => %w[placement plan course phrases first_cards]
    }.freeze

    DEFAULT_TRACK = "phonetics"

    def initialize(user)
      @user = user
    end

    def track = TRACKS.key?(user.start_level) ? user.start_level : DEFAULT_TRACK

    def steps
      current_assigned = false

      track_steps.map do |step|
        state = if done?(step)
          :done
        elsif !current_assigned && !step.optional?
          current_assigned = true
          :current
        else
          :todo
        end

        {
          key: step.key,
          state:,
          optional: step.optional?,
          theory: step.theory?,
          route: step.route,
          progress: progress_for(step)
        }
      end
    end

    def complete? = track_steps.reject(&:optional?).all? { |step| done?(step) }

    def done_count = track_steps.count { |step| done?(step) }

    def total_count = track_steps.length

    private

    attr_reader :user

    def track_steps = TRACKS.fetch(track).map { |key| STEPS.fetch(key) }

    def done?(step)
      return true if user.path_steps_done.include?(step.key)

      case step.auto
      when nil
        false
      when :reviews
        review_count >= FIRST_CARDS_TARGET
      when :placement
        placement_finished?
      when :course
        course_started?
      else
        user.practice_runs[step.auto.to_s].to_i.positive?
      end
    end

    def progress_for(step)
      return nil unless step.auto == :reviews

      {done: review_count.clamp(0, FIRST_CARDS_TARGET), target: FIRST_CARDS_TARGET}
    end

    def review_count
      @review_count ||= LexemeReview.where(user_id: user.id).limit(FIRST_CARDS_TARGET).count
    end

    def placement_finished?
      return @placement_finished if defined?(@placement_finished)

      @placement_finished = PlacementTest.where(user_id: user.id).where.not(status: :in_progress).exists?
    end

    def course_started?
      return @course_started if defined?(@course_started)

      @course_started = CourseCompletion.owned_by(user).finished.exists?
    end
  end
end
