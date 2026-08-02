# frozen_string_literal: true

module Voiced
  extend ActiveSupport::Concern

  included do
    helper_method :voice_profile, :voice_calibrated?
  end

  private

  def voice_profile
    return nil if Current.user.nil?
    return @voice_profile if defined?(@voice_profile)

    @voice_profile = VoiceProfile.find_by(user: Current.user)
  end

  def voice_calibrated?
    voice_profile&.calibrated? || false
  end
end
