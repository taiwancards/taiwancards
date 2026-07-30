# frozen_string_literal: true

module Huayu
  class MoeRevised
    PATH = AppData.path("huayu/moe_revised.jsonl")
    TITLE = /\A\{"t":"(.+?)"/
    ATTRIBUTION = "教育部《重編國語辭典修訂本》"
    LIMIT = 3
    STRIDE = 256
    BLOCK = 128 * 1024

    Sense = Data.define(:gloss, :pos, :reading, :examples)
    Result = Data.define(:text, :senses) do
      def any? = senses.any?
    end

    EMPTY = Result.new(text: nil, senses: [])

    class << self
      def for(text, limit: LIMIT)
        payload = lookup(text.to_s)
        return EMPTY if payload.nil?

        Result.new(text: payload["t"], senses: build(payload["s"], limit))
      end

      def covers?(text) = !lookup(text.to_s).nil?

      def available? = anchors.any?

      def blocks = anchors.length

      def reset!
        @anchors = nil
        @lines = nil
      end

      private

      def lookup(text)
        return nil if text.empty? || anchors.empty?

        start = block_for(text)
        return nil if start.nil?

        scan(start, text)
      end

      def block_for(text)
        position = anchors.bsearch_index { |(title, _)| title > text }
        return anchors.last.last if position.nil?
        return nil if position.zero? && anchors.first.first > text

        anchors[position - 1].last
      end

      def scan(offset, text)
        File.open(PATH, "rb") do |file|
          file.seek(offset)
          file.each_line do |line|
            title = line[TITLE, 1]&.force_encoding(Encoding::UTF_8)
            next if title.nil?
            return JSON.parse(line) if title == text
            break if title > text
          end
        end

        nil
      rescue JSON::ParserError, SystemCallError
        nil
      end

      def build(rows, limit)
        Array(rows).first(limit).map do |row|
          Sense.new(gloss: row["gloss"], pos: row["pos"], reading: row["reading"], examples: Array(row["examples"]))
        end
      end

      def anchors
        @anchors ||= build_anchors
      end

      def build_anchors
        return [] unless PATH.exist?

        marks = []
        offset = 0
        counter = 0
        File.open(PATH, "rb") do |file|
          file.each_line do |line|
            if (counter % STRIDE).zero?
              title = line[TITLE, 1]
              marks << [title.force_encoding(Encoding::UTF_8), offset] if title
            end

            offset += line.bytesize
            counter += 1
          end
        end

        marks
      end
    end
  end
end
