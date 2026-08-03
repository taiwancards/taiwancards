# frozen_string_literal: true

module Huayu
  class GrammarMatcher
    PATH = AppData.path("huayu/tocfl_grammar_attestation.json")

    class << self
      def lessons_for(text, limit: 6)
        candidates = compiled.filter_map do |entry|
          next unless matches?(text, entry[:markers])

          entry
        end

        candidates
          .sort_by { |entry| [-entry[:weight], -entry[:level]] }
          .first(limit)
          .map { |entry| entry[:lesson] }
      end

      def reset! = @compiled = nil

      private

      def compiled
        @compiled ||= begin
          lessons = GrammarLessons.all.index_by(&:id)
          points = PATH.exist? ? JSON.parse(PATH.read)["points"] : []
          points.filter_map do |point|
            lesson = lessons[point["id"]]
            markers = point["markers"]
            next if lesson.nil? || markers.nil?
            next if markers != "A-not-A" && !markers.is_a?(Array)

            {
              lesson: lesson,
              level: point["level"].to_i,
              markers: markers,
              weight: weight(markers)
            }
          end
        end
      end

      def weight(markers)
        return 3 if markers == "A-not-A"

        markers.flatten.map(&:length).sum
      end

      def matches?(text, markers)
        return !!text.match(/([一-鿿])不\1/) if markers == "A-not-A"

        position = 0
        markers.all? do |part|
          best = nil
          part.each do |alternative|
            alternative = [alternative] if alternative.is_a?(String)
            cursor = position
            found = alternative.all? do |marker|
              at = text.index(marker, cursor)
              at && (cursor = at + marker.length)
            end

            best = cursor if found && (best.nil? || cursor < best)
          end

          best && (position = best)
        end
      end
    end
  end
end
