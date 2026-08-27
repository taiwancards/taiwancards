# frozen_string_literal: true

module MarkedEntries
  extend ActiveSupport::Concern

  MARK_LIMIT = 6

  private

  def marked_texts
    @marked_texts ||= params[:mark].to_s.split(",").filter_map { |value| value.strip.presence }.uniq.first(MARK_LIMIT)
  end

  def marked_entries(scope)
    return [] if marked_texts.empty?

    scope.where(text: marked_texts).to_a
  end
end
