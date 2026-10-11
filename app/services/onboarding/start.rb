# frozen_string_literal: true

module Onboarding
  class Start
    UNKNOWN = "unknown"
    ZERO = "zero"
    GRADES = (1..7).map(&:to_s).freeze
    LEVELS = [ZERO, *GRADES, UNKNOWN].freeze
    KNOWN = %w[zero phonetics zhuyin].freeze
    OPTIONAL_FOR = %w[classes].freeze
    SEASONED_FROM = 3

    def initialize(user, goal:, level:, known:)
      @user = user
      @goal = goal.to_s.presence_in(User::GOALS)
      @level = level.to_s.presence_in(LEVELS)
      @known = known.to_s.presence_in(KNOWN) || ZERO
    end

    def valid?
      return false if @goal.nil?
      return true if @user.start_chosen? || OPTIONAL_FOR.include?(@goal)

      @level.present?
    end

    def call
      asked = !@user.start_chosen? && @level.present?
      @user.goal = @goal
      apply_level if asked
      @user.save!
      reseat if asked && stated_grade? && OPTIONAL_FOR.exclude?(@goal)
    end

    def placement? = @level == UNKNOWN && OPTIONAL_FOR.exclude?(@goal)

    private

    def stated_grade? = GRADES.include?(@level)

    def apply_level
      if stated_grade?
        @user.start_level = @level.to_i >= SEASONED_FROM ? "experienced" : "characters"
        @user.level = @level
        @user.write_prefs("path_steps" => @user.path_steps_done | %w[placement])
      elsif @level == UNKNOWN
        @user.start_level = "characters" unless OPTIONAL_FOR.include?(@goal)
      else
        @user.choose_start(@known)
      end
    end

    def reseat = Placement::Seeder.new(@user).reseat(@user.level_grade)
  end
end
