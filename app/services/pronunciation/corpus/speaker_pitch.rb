# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    module SpeakerPitch
      PATH = "speaker_pitch.json"
      MIN_HZ = 50.0

      module_function

      def path = File.join(TemplateStore.instance.root, PATH)

      def reference
        @reference ||= File.exist?(path) ? JSON.parse(File.read(path)) : build!
      end

      def reset! = @reference = nil

      def build!
        collected = Hash.new { |hash, speaker| hash[speaker] = [] }

        FanOut.map(Tokens.available) { |chunk| gather(chunk) }.each do |partial|
          partial.each { |speaker, values| collected[speaker].concat(values) }
        end

        @reference = collected.transform_values { |values| Acoustic::Dsp.median(values) }
        File.write(path, JSON.pretty_generate(@reference))
        @reference
      end

      def gather(keys)
        collected = Hash.new { |hash, speaker| hash[speaker] = [] }

        keys.each do |key|
          Tokens.each(key) do |row|
            hz = row["f0_ref_hz"].to_f
            collected[row["_speaker"]] << hz if hz > MIN_HZ
          end
        end

        collected
      end

      def register(speaker, hz)
        base = reference[speaker]
        return nil if base.nil? || base <= MIN_HZ || hz.to_f <= MIN_HZ

        12.0 * Math.log2(hz / base)
      end
    end
  end
end
