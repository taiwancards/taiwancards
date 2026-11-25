# frozen_string_literal: true

module Onboarding
  class Entry
    DOORS = %w[exam words text lookup].freeze
    PASTED = %w[words text].freeze
    GOALS = {"exam" => "tocfl", "words" => "classes"}.freeze
    STEPS = %i[sign_in language door questionnaire home].freeze
    DOOR_PAGES = {
      "exams#index" => "exam",
      "exams#show" => "exam",
      "doors#words" => "words",
      "doors#text" => "text"
    }.freeze

    def self.door(value) = value.to_s.presence_in(DOORS)

    def self.door_behind(path)
      return nil if path.blank?

      route = Rails.application.routes.recognize_path(path.split("?").first)
      endpoint = "#{route[:controller]}##{route[:action]}"
      endpoint == "doors#continue" ? door(route[:door]) : DOOR_PAGES[endpoint]
    rescue ActionController::RoutingError
      nil
    end

    def self.goal_for(door) = GOALS[door.to_s]

    def self.admit(user, door:, language_settled:)
      door = self.door(door)
      return user if door.nil?

      user.entry_door = door
      user.goal = goal_for(door) if goal_for(door)
      user.language_chosen = true if language_settled
      user.save!
      user
    end

    attr_reader :user, :door

    def initialize(user:, door: nil)
      @user = user
      @door = self.class.door(door)
    end

    def step
      return :sign_in if user.nil?
      return :language if door && !language_known?
      return :door if door
      return :questionnaire unless settled?

      :home
    end

    def questionnaire? = step == :questionnaire

    def offer_setup? = user.present? && user.entry_door.present? && !user.start_chosen?

    private

    def language_known? = user.language_chosen? || user.entry_door.nil?

    def settled? = user.goal_chosen? || user.entry_door.present?
  end
end
