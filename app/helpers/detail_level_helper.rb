# frozen_string_literal: true

module DetailLevelHelper
  DETAIL_COOKIE = "dict_detail"
  FULL = "full"
  BRIEF = "brief"
  DETAIL_MODES = [FULL, BRIEF].freeze

  def detail_mode
    @detail_mode ||= cookies[DETAIL_COOKIE].to_s.presence_in(DETAIL_MODES) || FULL
  end

  def detailed?
    detail_mode == FULL
  end

  def brief?
    !detailed?
  end
end
