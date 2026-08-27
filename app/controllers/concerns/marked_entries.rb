# frozen_string_literal: true

module MarkedEntries
  extend ActiveSupport::Concern

  MARK_LIMIT = 6

  private

  def marked_texts
    @marked_texts ||= params[:mark].to_s.split(",").filter_map { |value| value.strip.presence }.uniq.first(MARK_LIMIT)
  end

  def marked_page(scope, per_page)
    return nil if marked_texts.empty? || params[:page].present?

    marks = marked_texts.to_set
    position = scope.pluck(:text).index { |text| marks.include?(text) }
    position && (position / per_page) + 1
  end
end
