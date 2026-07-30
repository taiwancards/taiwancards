# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    module Tokens
      TAIWAN = "tokens"
      MAINLAND = "tokens_mainland"

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

      def each(key, source = TAIWAN)
        path = File.join(root(source), "#{key}.jsonl")
        return to_enum(:each, key, source) unless block_given?
        return unless File.exist?(path)

        File.foreach(path) do |line|
          row = begin
            JSON.parse(line)
          rescue JSON::ParserError
            next
          end

          yield(row)
        end
      end

      def sample(key, limit, source = TAIWAN)
        rows = []
        each(key, source) { |row| rows << row }
        return rows if rows.length <= limit

        step = rows.length.to_f / limit
        Array.new(limit) { |i| rows[(i * step).floor] }
      end

      def count(keys, source = TAIWAN)
        keys.sum { |key| each(key, source).count }
      end
    end
  end
end
