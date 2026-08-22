# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class CommonVoiceTokens
      DIR = "corpus_cv"
      CLIPS = "manifest.json"
      FILE = "tokens.json"
      SOURCE = "common_voice"
      MIN_SYLLABLES = 2
      MAX_SYLLABLES = 5
      DESCRIPTION = "Common Voice zh-TW, дикторы с тайваньским местом рождения — связная речь многих голосов"

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
      end

      def write!
        payload = call
        path = File.join(@store.root, DIR, FILE)
        File.write(path, JSON.generate(payload))
        @io&.puts("  wrote #{path}")
        path
      end

      def call
        wanted = clips
        raise "no clips under #{DIR}" if wanted.empty?

        reader = TextReading.new(index: readings(wanted))
        tokens = Hash.new { |hash, key| hash[key] = [] }
        resolved = 0

        wanted.each do |clip|
          rows = Huayu::TextReading.rows(clip[:text], reader.spell(clip[:segments]))
          next if rows.empty?

          resolved += 1
          rows.each_with_index do |row, index|
            tokens[row["key"]] << entry(clip, row, index, rows.length)
          end
        end

        @io&.puts(
          "  clips #{wanted.length}, read #{resolved}, keys #{tokens.length}, tokens #{tokens.values.sum(&:length)}"
        )

        {
          "generated_at" => Time.current.utc.iso8601,
          "sample_rate" => 22_050,
          "norm" => "taiwan",
          "sources" => {SOURCE => DESCRIPTION},
          "tokens" => tokens
        }
      end

      private

      TextReading = Huayu::TextReading

      def entry(clip, row, index, total)
        {
          "source" => SOURCE,
          "index" => index,
          "n_syllables" => total,
          "transcript" => row["char"],
          "pinyin" => row["pinyin"],
          "speaker" => clip[:speaker],
          "norm" => "taiwan",
          "path" => "data/#{DIR}/audio/#{clip[:file]}"
        }
      end

      def clips
        path = File.join(@store.root, DIR, CLIPS)
        return [] unless File.exist?(path)

        analyzer = Huayu::TextAnalyzer.new
        JSON.parse(File.read(path))["clips"].to_a.filter_map do |name, meta|
          text = meta["sentence"].to_s
          length = text.scan(Huayu::TextReading::HAN).length
          next unless length.between?(MIN_SYLLABLES, MAX_SYLLABLES)

          file = File.basename(meta["path"].to_s.presence || name, ".*") + ".wav"
          next unless File.exist?(File.join(@store.root, DIR, "audio", file))

          {file: file, text: text, speaker: meta["speaker"], segments: analyzer.segment(text)}
        end
      end

      def readings(wanted)
        texts = wanted.flat_map { |clip| clip[:segments] + clip[:text].scan(Huayu::TextReading::HAN) }.uniq
        Lexeme
          .where(kind: Huayu::TextAnalyzer::TOKEN_KINDS, text: texts)
          .order(:kind)
          .each_with_object({}) { |lexeme, acc| acc[lexeme.text] ||= lexeme.readings["pinyin"] }
      end
    end
  end
end
