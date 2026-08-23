# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    module ContextNorms
      PATH = "context_norms.json"
      EDGE = 0

      module_function

      def data
        @data ||= read
      end

      def reset! = @data = nil

      def read
        path = File.join(TemplateStore.instance.root, PATH)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        {}
      end

      VOICELESS = %w[f s sh x h p t k c ch q].freeze
      VOICED = %w[m n l r].freeze

      def curves = data["curves"] || {}

      def onset_class(initial)
        return "vowel" if initial == ""
        return "voiceless" if VOICELESS.include?(initial)
        return "nasal" if VOICED.include?(initial)

        "voiced"
      end

      def coda_factor(initial)
        return nil if initial.nil?

        (data["coda"] || {})[onset_class(initial)]
      end

      def stretch(spot)
        return nil if spot == "alone"

        (data["duration"] || {})[spot]
      end

      def position(index, total)
        return "alone" if total <= 1
        return "first" if index.zero?

        index == total - 1 ? "last" : "middle"
      end

      def spot_of(before, following)
        return "alone" if before.to_i.zero? && following.to_i.zero?
        return "first" if before.to_i.zero?

        following.to_i.zero? ? "last" : "middle"
      end

      def cell(tone, before, following)
        "#{tone.to_i},#{before.to_i},#{following.to_i}"
      end

      def shift(tone, before, following)
        curves[cell(tone, before, following)]
      end

      def place(centre, tone, before, following)
        return centre if centre.blank? || tone.to_i.zero?

        moved = shift(tone, before, following)
        return centre if moved.nil? || moved.length != centre.length

        centre.each_index.map { |i| centre[i] + moved[i] }
      end
    end
  end
end
