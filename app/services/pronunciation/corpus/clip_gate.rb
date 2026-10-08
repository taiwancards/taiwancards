# frozen_string_literal: true

module Pronunciation
  module Corpus
    module ClipGate
      MAX_FLATNESS = 160.0
      MIN_PITCH_CONF = 0.80
      MAX_HUM_SHARE = 0.005
      MAX_CLIP_SHARE = 0.002

      module_function

      def good?(row) = reasons(row).empty?

      def reasons(row)
        quality = row["_quality"]
        return [] if quality.blank?

        out = []
        out << "flatness" if over?(quality["flatness"], MAX_FLATNESS)
        out << "pitch" if under?(quality["pitch_conf"], MIN_PITCH_CONF)
        out << "hum" if over?(quality["hum_share"], MAX_HUM_SHARE)
        out << "clipping" if over?(quality["clip_share"], MAX_CLIP_SHARE)
        out
      end

      def over?(value, limit) = !value.nil? && value > limit

      def under?(value, limit) = !value.nil? && value < limit
    end
  end
end
