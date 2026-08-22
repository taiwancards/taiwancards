# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class JunctionNorms
      SOURCE = "corpus_cv"
      FILE = "junction_norms.json"
      MIN_SYLLABLES = 2
      MAX_SYLLABLES = 6
      MIN_CELL = 60
      MEASURES = {"gap_ms" => "gap_ms", "f0_jump" => "f0_jump", "dip_db" => "dip_db"}.freeze
      QUANTILES = {"p50" => 0.5, "p75" => 0.75, "p90" => 0.9}.freeze

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
      end

      def write!
        path = File.join(@store.root, FILE)
        File.write(path, JSON.generate(call))
        @io&.puts("  wrote #{path}")
        path
      end

      def call
        clips = readable
        raise "no clips under #{SOURCE}" if clips.empty?

        @io&.puts("Junction norms over #{clips.length} native recordings")
        merged = Hash.new { |hash, cell| hash[cell] = Hash.new { |inner, name| inner[name] = [] } }
        FanOut.map(clips, io: @io) { |chunk| measure(chunk) }.each do |chunk|
          chunk.each { |cell, rows| rows.each { |name, values| merged[cell][name].concat(values) } }
        end

        {
          "generated_at" => Time.current.utc.iso8601,
          "source" => SOURCE,
          "n_clips" => clips.length,
          "classes" => summarize(merged)
        }
      end

      private

      def readable
        path = File.join(@store.root, SOURCE, "manifest.json")
        return [] unless File.exist?(path)

        cache = {}
        JSON.parse(File.read(path))["clips"].to_a.filter_map do |_, meta|
          audio = File.join(@store.root, SOURCE, "audio", File.basename(meta["path"]))
          next unless File.exist?(audio)

          characters = meta["sentence"].to_s.scan(/\p{Han}/)
          next unless characters.length.between?(MIN_SYLLABLES, MAX_SYLLABLES)

          keys = characters.map { |character| key_of(character, cache) }
          next if keys.any?(&:nil?)

          [audio, keys]
        end
      end

      def measure(clips)
        out = Hash.new { |hash, cell| hash[cell] = Hash.new { |inner, name| inner[name] = [] } }

        clips.each do |audio, keys|
          signal = DSP.read(audio)
          analysis = Acoustic::Features.analyze(signal.samples, signal.sample_rate)
          spans = Acoustic::Features.syllable_spans(analysis, keys.length)
          next if spans.nil?

          Acoustic::Junctions.measure(analysis, spans).compact.each do |junction|
            cell = Acoustic::Junctions.cell(keys[junction["index"] + 1])
            MEASURES.each_key do |name|
              value = junction[name]
              out[cell][name] << value unless value.nil?
              out["all"][name] << value unless value.nil?
            end
          end

        rescue StandardError
          next
        end

        FanOut.plain(out)
      end

      def key_of(character, cache)
        cache.fetch(character) do
          reading = Lexeme.find_by(kind: %i[character word], text: character)&.readings&.dig("pinyin")
          pinyin = reading.is_a?(Array) ? reading.first : reading
          cache[character] = pinyin && SyllableKey.for({"pinyin" => pinyin}, store: @store)
        end
      end

      def summarize(merged)
        merged
          .filter_map do |cell, rows|
            next if rows["gap_ms"].length < MIN_CELL

            [cell, rows.transform_values { |values| quantiles(values) }]
          end
          .to_h
      end

      def quantiles(values)
        sorted = values.sort
        QUANTILES
          .transform_values { |share| sorted[[(sorted.length * share).to_i, sorted.length - 1].min].round(3) }
          .merge("n" => sorted.length)
      end
    end
  end
end
