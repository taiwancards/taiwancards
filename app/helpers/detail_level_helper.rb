# frozen_string_literal: true

module DetailLevelHelper
  DETAIL_COOKIE = "dict_detail"
  DETAIL_MODES = [Lexemes::DetailDefault::FULL, Lexemes::DetailDefault::BRIEF].freeze

  def detail_mode
    @detail_mode ||= cookies[DETAIL_COOKIE].to_s.presence_in(DETAIL_MODES) ||
      Lexemes::DetailDefault.new(Current.user).call
  end

  def detailed?
    detail_mode == Lexemes::DetailDefault::FULL
  end

  def brief?
    !detailed?
  end
end
