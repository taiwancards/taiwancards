# frozen_string_literal: true

module Learn
  class NextStep
    Step = Data.define(:kind, :reason)

    PHONETIC_STEPS = %w[zhuyin bridge drill typing].freeze

    def initialize(user)
      @user = user
    end

    def call
      pending = pending_phonetic_step
      return Step.new(kind: pending, reason: "phonetics") if pending

      Step.new(kind: "study", reason: study_reason)
    end

    private

    attr_reader :user

    def pending_phonetic_step
      return nil if user.level_grade.positive?

      path = Onboarding::Path.new(user)
      step = path.steps.find { |item| PHONETIC_STEPS.include?(item[:key]) && item[:state] != :done }
      step && step[:key]
    end

    def study_reason
      user.level_grade.positive? ? "level" : "starting"
    end
  end
end
