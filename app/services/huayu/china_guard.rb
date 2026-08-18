# frozen_string_literal: true

module Huayu
  class ChinaGuard
    extend MemoizedInstance

    class << self
      delegate :offender, :marker?, :soft_offender, to: :instance
    end

    def initialize
      @markers = load_markers
    end

    ERHUA = "兒"

    def offender(text)
      value = text.to_s
      @markers.find { |marker| value.include?(marker) } || erhua_offender(value)
    end

    def soft_offender(text)
      value = text.to_s
      TWFilter::Checks::Lexicon.soft_terms.each_key.find { |marker| value.include?(marker) }
    end

    def marker?(text) = !offender(text).nil?

    private

    def erhua_offender(value)
      hit = TWFilter::Checks::Erhua.offender(value)
      return nil if hit.nil?
      return hit unless hit.include?(ERHUA)

      value.end_with?(ERHUA) ? hit : nil
    end

    def load_markers
      stored = ChinaMarker.hard.pluck(:word) if ChinaMarker.table_exists?
      return stored.to_set if stored.present?

      TWFilter::Checks::Lexicon.hard_terms.keys.to_set
    rescue ActiveRecord::ActiveRecordError
      TWFilter::Checks::Lexicon.hard_terms.keys.to_set
    end
  end
end
