# frozen_string_literal: true

module Graded
  class Readings
    def initialize(analyzer: Huayu::TextAnalyzer.new)
      @readings = Huayu::SentenceReadings.new(analyzer:)
    end

    def lines(text)
      @readings.call(text.lines.map(&:zh))
    end
  end
end
