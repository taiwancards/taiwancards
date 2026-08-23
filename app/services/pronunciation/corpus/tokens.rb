# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    module Tokens
      TAIWAN = "tokens"
      CHINA = "tokens_mainland"

      module_function

      def root(source = TAIWAN)
        source.start_with?("/") ? source : File.join(TemplateStore.instance.root, source)
      end

      def split
        @split ||= begin
          path = File.join(TemplateStore.instance.root, "test_split.json")
          File.exist?(path) ? JSON.parse(File.read(path)) : {}
        end
      end

      HELD_OUT = "held_out_speakers"

      def held_out_speakers
        @held_out_speakers ||= Array(split[HELD_OUT]).to_set
      end

      def reset!
        @split = nil
        @held_out_speakers = nil
        @available = nil
      end

      def wanted?(row, speakers)
        return true if speakers == :all
        return speakers.include?(row["_speaker"]) if speakers.is_a?(Enumerable)
        return true if held_out_speakers.empty?

        (speakers == :held_out) == held_out_speakers.include?(row["_speaker"])
      end

      def keys(part, source = TAIWAN)
        return available(source) if part.to_s == "all"

        Array(split[part.to_s]) & available(source)
      end

      def available(source = TAIWAN)
        @available ||= {}
        @available[source] ||= Dir
          .glob(File.join(root(source), "*.jsonl"))
          .map { |path| File.basename(path, ".jsonl") }
          .sort
      end

      def each(key, source = TAIWAN, speakers: :fitting, raw: false)
        path = File.join(root(source), "#{key}.jsonl")
        return to_enum(:each, key, source, speakers: speakers, raw: raw) unless block_given?
        return unless File.exist?(path)

        File.foreach(path) do |line|
          row = begin
            JSON.parse(line)
          rescue JSON::ParserError
            next
          end

          next unless wanted?(row, speakers)

          yield(raw ? row : enrich(row))
        end
      end

      def enrich(row)
        Acoustic::Vowel.place(row, SpeakerPitch.reference[row["_speaker"]])
      end

      def sample(key, limit, source = TAIWAN, speakers: :fitting)
        rows = []
        each(key, source, speakers: speakers) { |row| rows << row }
        return rows if rows.length <= limit

        step = rows.length.to_f / limit
        Array.new(limit) { |i| rows[(i * step).floor] }
      end

      def count(keys, source = TAIWAN, speakers: :fitting)
        keys.sum { |key| each(key, source, speakers: speakers).count }
      end
    end
  end
end
