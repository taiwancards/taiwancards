# frozen_string_literal: true

module VoiceHelpers
  def warm_up!(user = current_user)
    VoiceProfile.find_or_create_by!(user: user).tap do |profile|
      profile.update!(f3_ref: 2900, calibrated_at: Time.current)
    end
  end
end

RSpec.configure do |config|
  config.include(VoiceHelpers, type: :request)
end
