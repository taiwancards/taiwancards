# frozen_string_literal: true

module Introduced
  extend ActiveSupport::Concern

  ALWAYS_ALLOWED = %w[intros sessions locales omniauth_callbacks rails/health].freeze

  included do
    before_action :settle_intro
    helper_method :intro_progress, :intro_required?
  end

  class_methods do
    def allow_before_intro(**options)
      skip_before_action(:settle_intro, **options)
    end
  end

  private

  def intro_progress
    @intro_progress ||= current_user&.intro
  end

  def intro_required?
    Intro.gated? && (intro_progress&.required? || false)
  end

  def settle_intro
    return unless intro_required?
    return if ALWAYS_ALLOWED.include?(controller_path)
    return unless request.get? || request.head?

    intro_progress.arrived_at(request.path)
    return if intro_progress.allows?(request.path)

    destination = intro_progress.step&.path
    return if destination.blank? || same_path?(destination)

    redirect_to(destination)
  end

  def same_path?(destination)
    destination.split("?").first.chomp("/") == request.path.chomp("/")
  end
end
