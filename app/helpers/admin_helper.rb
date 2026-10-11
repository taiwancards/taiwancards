# frozen_string_literal: true

module AdminHelper
  REGIONAL_INDICATOR_OFFSET = 0x1F1A5

  def country_flag(code)
    code.to_s.each_char.map { |char| (char.ord + REGIONAL_INDICATOR_OFFSET).chr(Encoding::UTF_8) }.join
  end

  def whereabouts(user)
    place = user.country.presence && "#{country_flag(user.country)} #{user.country}"
    [place, user.time_zone.presence].compact.join(" · ")
  end
end
