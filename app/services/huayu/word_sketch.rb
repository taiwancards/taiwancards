# frozen_string_literal: true

module Huayu
  class WordSketch
    PATH = AppData.path("huayu/word_sketches.jsonl")
    HEAD = /\A\{"h":"(.+?)"/
    LIMIT = 8

    RELATIONS = %w[
      modifier
      modified
      verb_object
      manner
      complement
      degree
      resultative
      aspect
      negated
      preposition
      disposal
      passive
      classifier
      construction
    ]
      .freeze

    Collocate = Data.define(:text, :score, :count)
    Relation = Data.define(:name, :collocates)
    Result = Data.define(:head, :relations) do
      def any? = relations.any?
    end

    EMPTY = Result.new(head: nil, relations: [])

    class << self
      def for(text, limit: LIMIT)
        offset, length = index[text.to_s]
        return EMPTY if offset.nil?

        payload = JSON.parse(IO.read(PATH, length, offset))
        Result.new(head: payload["h"], relations: relations_from(payload["r"], limit))
      rescue JSON::ParserError
        EMPTY
      end

      def covers?(text) = index.key?(text.to_s)

      def available? = index.any?

      def size = index.size

      def reset! = @index = nil

      private

      def relations_from(raw, limit)
        ordered = RELATIONS & raw.keys
        (ordered + (raw.keys - ordered)).map do |name|
          collocates = Array(raw[name]).first(limit).map do |(text, score, count)|
            Collocate.new(text:, score:, count:)
          end

          Relation.new(name:, collocates:)
        end
      end

      def index
        @index ||= build
      end

      def build
        return {} unless PATH.exist?

        map = {}
        offset = 0
        File.open(PATH, "rb") do |file|
          file.each_line do |line|
            head = line[HEAD, 1]
            map[head.force_encoding(Encoding::UTF_8)] = [offset, line.bytesize] if head
            offset += line.bytesize
          end
        end

        map
      end
    end
  end
end
