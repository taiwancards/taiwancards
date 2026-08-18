# frozen_string_literal: true

module Huayu
  class SyllableChart
    INITIALS = %w[b p m f d t n l g k h j q x zh ch sh r z c s].freeze
    ZERO = "∅"
    TONES = [1, 2, 3, 4, 5].freeze

    Syllable = Data.define(:base, :zhuyin, :clips) do
      def clip(tone) = clips[tone]
    end

    Group = Data.define(:initial, :syllables)

    class << self
      def groups = build.fetch(:groups)

      def size = build.fetch(:size)

      def bases = build.fetch(:bases)

      def voices = CnsVoice::VOICES

      def templates = CnsVoice::VOICES.index_with { |voice| CnsVoice.clip_url_template(voice) }

      def reset! = remove_instance_variable(:@build) if defined?(@build)

      private

      def build
        @build ||= assemble
      end

      def assemble
        table = CnsVoice.table
        by_base = Hash.new { |hash, key| hash[key] = {} }
        zhuyin_of = {}

        table.each do |zhuyin, key|
          base = key.sub(/[1-5]\z/, "")
          tone = key[/[1-5]\z/]&.to_i || 1
          by_base[base][tone] = key
          zhuyin_of[base] ||= zhuyin.delete(CnsVoice::NEUTRAL)
        end

        syllables = by_base.map { |base, clips| Syllable.new(base:, zhuyin: zhuyin_of[base], clips:) }
        {groups: group(syllables), size: table.size, bases: syllables.length}
      end

      def group(syllables)
        buckets = syllables.group_by { |syllable| initial_of(syllable.base) }
        ordered = INITIALS + [ZERO]
        ordered.filter_map do |initial|
          found = buckets[initial]
          next if found.nil?

          Group.new(initial:, syllables: found.sort_by(&:base))
        end
      end

      def initial_of(base)
        INITIALS.select { |initial| base.start_with?(initial) }.max_by(&:length) || ZERO
      end
    end
  end
end
