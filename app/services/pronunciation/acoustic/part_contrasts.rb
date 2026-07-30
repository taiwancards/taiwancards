# frozen_string_literal: true

module Pronunciation
  module Acoustic
    class PartContrasts
      PARTS = %w[initial medial final tone].freeze

      def initialize(store)
        @store = store
        @profiles = {}
      end

      def distances(features, key, norm)
        profiles(key, norm)
          .filter_map do |part, profile|
            template = @store.template(key, norm) || @store.template(key)
            next if template.nil?

            distance = Contrasts.weighted_distance(features, template, profile)
            [part, distance] if distance
          end
          .to_h
      end

      def profiles(key, norm)
        @profiles[[key, norm]] ||= build_profiles(key, norm)
      end

      private

      def build_profiles(key, norm)
        target = @store.template(key, norm) || @store.template(key)
        return {} if target.nil?

        PartRivals
          .keys_by_part(key)
          .filter_map do |part, rival_keys|
            merged = merge(target, rival_keys, norm)
            [part, merged] if merged.present?
          end
          .to_h
      end

      def merge(target, rival_keys, norm)
        merged = {}

        rival_keys.each do |rival_key|
          rival = @store.template(rival_key, norm) || @store.template(rival_key)
          next if rival.nil?

          Contrasts.profile(target, rival).each do |field, info|
            merged[field] = info if merged[field].nil? || info["d"] > merged[field]["d"]
          end
        end

        merged
      end
    end
  end
end
