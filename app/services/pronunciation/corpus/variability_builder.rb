# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class VariabilityBuilder
      PATH = "variability.json"
      DIR = "corpus_cv"
      MIN_CHARS = 2
      MAX_CHARS = 5
      MIN_AUDIO_S = 0.3
      MIN_SPEAKERS = 3
      MIN_HZ = 50.0

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @root = File.join(store.root, DIR)
        @io = io
      end

      def call
        rows = features
        registered = with_register(rows)
        by_key = registered.group_by { |row| row["_key"] }
        model = StyleFactor
          .new(store: @store)
          .correct(Acoustic::Variability.estimate(by_key, min_speakers: MIN_SPEAKERS))

        {
          "source" => "#{corpus_release}, speakers born in Taiwan",
          "note" => "the template center stays Taiwan citation form; only the tolerance width comes from here",
          "n_speakers" => registered.map { |row| row["_speaker"] }.uniq.length,
          "n_tokens" => registered.length,
          "model" => model
        }
      end

      def write!
        payload = call
        File.write(File.join(@store.root, PATH), JSON.pretty_generate(payload))
        @io&.puts("speakers #{payload["n_speakers"]}, tokens #{payload["n_tokens"]}")
        payload
      end

      private

      def corpus_release
        manifest = File.join(@root, "manifest.json")
        return DIR unless File.exist?(manifest)

        JSON.parse(File.read(manifest))["source"] || DIR
      end

      def features
        items = clips
        @io&.puts(
          "  recordings #{items.length}, speakers #{items.map { |item| item[:speaker] }.uniq.length}"
        )

        FanOut.map(items, io: @io) { |chunk| chunk.flat_map { |item| analyze(item) } }.flatten(1)
      end

      def clips
        manifest = JSON.parse(File.read(File.join(@root, "manifest.json")))

        manifest["clips"].filter_map do |file, clip|
          chars = clip["sentence"].to_s.gsub(/[^\p{Han}]/, "").chars
          next unless chars.length.between?(MIN_CHARS, MAX_CHARS)

          keys = chars.map { |char| CharReadings.key_for(char) }
          next if keys.any?(&:nil?)

          {path: resolve(clip["path"], file), keys: keys, speaker: clip["speaker"]}
        end
      end

      def resolve(relative, file)
        candidate = File.join(@root, relative.to_s.sub(%r{\Adata/[^/]+/}, ""))
        File.exist?(candidate) ? candidate : File.join(@root, "audio", File.basename(file, ".*") + ".wav")
      end

      def analyze(item)
        return [] unless File.exist?(item[:path])

        signal = DSP.read(item[:path])
        return [] if signal.length < signal.sample_rate * MIN_AUDIO_S

        analysis = Acoustic::Features.analyze(signal.samples, signal.sample_rate)
        spans = Acoustic::Features.syllable_spans(analysis, item[:keys].length)
        return [] if spans.nil?

        rows(analysis, spans, item)
      rescue StandardError
        []
      end

      def rows(analysis, spans, item)
        item[:keys].each_with_index.filter_map do |key, index|
          span = spans[index]
          next if span.nil?
          next if (span[1] - span[0]) * Acoustic::Features::HOP_MS < Ingest::MIN_SPAN_MS

          initial = initial_of(key)
          Acoustic::Features
            .extract(analysis, span, initial: initial, utterance_initial: index.zero?)
            .merge("_key" => key, "_speaker" => item[:speaker])
        end
      end

      def initial_of(key)
        parsed = Acoustic::Syllables.parse_key(key)
        parsed && Acoustic::Syllables.structure(parsed[0])[:initial]
      end

      def with_register(rows)
        by_speaker = Hash.new { |hash, speaker| hash[speaker] = [] }
        rows.each { |row| by_speaker[row["_speaker"]] << row["f0_ref_hz"] if row["f0_ref_hz"].to_f > MIN_HZ }
        refs = by_speaker.transform_values { |values| DTW::Statistics.median(values) }

        rows.each do |row|
          base = refs[row["_speaker"]]
          Acoustic::Vowel.place(row, base)
          row["f0_register"] = if base && base > MIN_HZ && row["f0_ref_hz"].to_f > MIN_HZ
            12.0 * Math.log2(row["f0_ref_hz"] / base)
          end
        end

        rows
      end
    end
  end
end
