# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class SpeakerSplit
      FILE = "test_split.json"

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
      end

      def write!
        chosen = call
        path = File.join(@store.root, FILE)
        payload = File.exist?(path) ? JSON.parse(File.read(path)) : {}
        payload[Tokens::HELD_OUT] = chosen
        payload["held_out_note"] = "voices no template is built from, so the report can measure a stranger"
        File.write(path, JSON.pretty_generate(payload))
        Tokens.reset!
        @io&.puts("  held out #{chosen.length} Common Voice speakers")
        path
      end

      def call = voices

      private

      def voices
        @voices ||= read_voices
      end

      def read_voices
        path = File.join(@store.root, CommonVoiceTokens::DIR, CommonVoiceTokens::FILE)
        return [] unless File.exist?(path)

        JSON
          .parse(File.read(path))["tokens"]
          .values
          .flatten(1)
          .map { |token| token["speaker"] }
          .uniq
          .sort
      end
    end
  end
end
