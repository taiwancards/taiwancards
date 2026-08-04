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

    here = Locales.strip(request.path)
    intro_progress.arrived_at(here)
    return if intro_progress.allows?(here)

    destination = intro_progress.step&.path
    return if destination.blank? || same_path?(destination, here)

    redirect_to(Locales.swap(destination, I18n.locale))
  end

  def same_path?(destination, here)
    destination.split("?").first.chomp("/") == here.chomp("/")
  end
end
