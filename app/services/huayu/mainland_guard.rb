# frozen_string_literal: true

module Huayu
  class MainlandGuard
    class << self
      def instance = @instance ||= new

      def reset! = @instance = nil

      delegate :offender, :marker?, :soft_offender, to: :instance
    end

    def initialize
      @markers = load_markers
    end

    def offender(text)
      value = text.to_s
      @markers.find { |marker| value.include?(marker) } || TWFilter::Checks::Erhua.offender(value)
    end

    def soft_offender(text)
      value = text.to_s
      TWFilter::Checks::Lexicon.soft_terms.each_key.find { |marker| value.include?(marker) }
    end

    def marker?(text) = !offender(text).nil?

    private

    def load_markers
      stored = MainlandMarker.hard.pluck(:word) if MainlandMarker.table_exists?
      return stored.to_set if stored.present?

      TWFilter::Checks::Lexicon.hard_terms.keys.to_set
    rescue ActiveRecord::ActiveRecordError
      TWFilter::Checks::Lexicon.hard_terms.keys.to_set
    end
  end
end
