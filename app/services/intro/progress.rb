# frozen_string_literal: true

module Intro
  class Progress
    def initialize(user)
      @user = user
    end

    attr_reader :user

    def required?
      user.present? && user.intro_running?
    end

    def pending?
      user.present? && !user.intro_done? && !user.intro_running?
    end

    def start!
      user.update!(prefs: user.prefs.merge("intro_stage" => "running"))
      step
    end

    def pause!
      user.update!(prefs: user.prefs.merge("intro_stage" => nil))
    end

    def step
      return nil unless required?

      steps = Map.essential
      steps.find { |candidate| candidate.id == user.intro_step } || steps.first
    end

    def position
      Map.essential.index(step).to_i
    end

    def length = Map.essential.length

    def last? = position >= length - 1

    def advance!
      following = Map.essential[position + 1]
      return finish! if following.nil?

      user.update!(prefs: user.prefs.merge("intro_step" => following.id))
      following
    end

    def rewind!
      previous = position.positive? ? Map.essential[position - 1] : Map.essential.first
      user.update!(prefs: user.prefs.merge("intro_step" => previous.id))
      previous
    end

    def finish!
      user.update!(
        prefs: user.prefs.merge(
          "intro_stage" => "done",
          "intro_step" => nil,
          "intro_version" => Map.version
        )
      )
      nil
    end

    def unseen
      return [] unless user&.intro_done?

      Map.newer_than(user.intro_seen_version)
    end

    def whats_new? = unseen.any?

    def acknowledge_new!
      user.update!(prefs: user.prefs.merge("intro_version" => Map.version))
    end

    def chapter_done?(id) = user.intro_chapters.include?(id.to_s)

    def complete_chapter!(id)
      user.update!(prefs: user.prefs.merge("intro_chapters" => (user.intro_chapters | [id.to_s]).last(20)))
    end

    def allows?(path)
      return true unless required?
      return true if step.nil? || step.path.blank?

      normalized(path) == normalized(step.path) || normalized(path) == normalized(step.lands_on)
    end

    def arrived_at(path)
      current = step
      return if current.nil? || current.lands_on.blank?
      return unless normalized(path) == normalized(current.lands_on)

      advance!
    end

    private

    def normalized(path)
      return nil if path.blank?

      path.to_s.split("?").first.to_s.chomp("/").presence || "/"
    end
  end
end
