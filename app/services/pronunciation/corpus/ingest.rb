# frozen_string_literal: true

require "json"
require "fileutils"

module Pronunciation
  module Corpus
    class Ingest
      MIN_SPAN_MS = 90.0
      MIN_AUDIO_S = 0.12

      def initialize(only: nil, manifest: Manifest.new, out: nil, io: nil, store: TemplateStore.instance)
        @only = only && Array(only).to_set
        @manifest = manifest
        @out = out || Tokens.root
        @io = io
        @store = store
      end

      attr_reader :out

      SPILL = ".parts"

      def write!
        groups = @manifest.by_file(only: @only)
        @io&.puts("  files #{groups.size}, tokens #{groups.values.sum(&:size)}")

        spill = File.join(@out, SPILL)
        FileUtils.rm_rf(spill)
        FileUtils.mkdir_p(spill)

        written = FanOut.map(groups.to_a, io: @io) { |chunk| spill_chunk(chunk, spill) }.sum
        @io&.puts("  features: #{written}")

        keys = collect(spill)
        FileUtils.rm_rf(spill)
        dropped = forget_stale(keys)
        @io&.puts("  keys written: #{keys.length}#{", stale removed: #{dropped}" if dropped.positive?}")
        keys
      end

      def forget_stale(keys)
        return 0 if @only

        wanted = keys.to_set
        stale = Dir.glob(File.join(@out, "*.jsonl")).reject { |path| wanted.include?(File.basename(path, ".jsonl")) }
        stale.each { |path| File.delete(path) }
        stale.length
      end

      private

      def spill_chunk(chunk, dir)
        written = 0

        File.open(File.join(dir, "#{Process.pid}.jsonl"), "w") do |io|
          chunk.each do |pair|
            analyze(pair).each do |row|
              io.puts(JSON.generate(row))
              written += 1
            end
          end
        end

        written
      end

      def collect(spill)
        grouped = Hash.new { |hash, key| hash[key] = [] }

        Dir.glob(File.join(spill, "*.jsonl")).sort.each do |path|
          File.foreach(path) do |line|
            key = line[/"_key":"([^"]+)"/, 1]
            grouped[key] << line unless key.nil?
          end
        end

        grouped.each { |key, lines| File.write(File.join(@out, "#{key}.jsonl"), lines.join) }
        grouped.keys
      end

      def analyze((relative, tokens))
        wanted = @only ? tokens.select { |token| @only.include?(token["_key"]) } : tokens
        return [] if wanted.empty?

        signal = DSP.read(@manifest.resolve(relative))
        return [] if signal.length < signal.sample_rate * MIN_AUDIO_S

        analysis = Acoustic::Features.analyze(signal.samples, signal.sample_rate)
        spans = segment(analysis, tokens)
        return [] if spans.nil?

        wanted.filter_map { |token| row(analysis, spans, token, relative) }
      rescue StandardError
        []
      end

      def segment(analysis, tokens)
        count = tokens.first["n_syllables"].to_i
        Acoustic::Features.syllable_spans(analysis, count) || aligner.spans(analysis, priors(tokens, count))
      end

      def priors(tokens, count)
        by_index = tokens.index_by { |token| token["index"].to_i }
        Array.new(count) do |index|
          key = by_index[index]&.fetch("_key", nil)
          next nil if key.nil?

          norm = @store.norm_for(position: index, total: count)
          @store.template(key, norm) || @store.template(key)
        end
      end

      def aligner = @aligner ||= Acoustic::Alignment.new

      def row(analysis, spans, token, relative)
        span = spans[token["index"]]
        return nil if span.nil?
        return nil if (span[1] - span[0]) * Acoustic::Features::HOP_MS < MIN_SPAN_MS

        st = structure_of(token["_key"])
        Acoustic::Features
          .extract(
            analysis,
            span,
            initial: st[:initial],
            utterance_initial: token["index"].to_i.zero?,
            nasal_coda: st[:nasal_coda].present?
          )
          .merge(
            "_key" => token["_key"],
            "_file" => File.basename(relative),
            "_index" => token["index"],
            "_speaker" => token["speaker"],
            "_source" => token["source"],
            "_n_syllables" => token["n_syllables"],
            "_transcript" => token["transcript"]
          )
      end

      def structure_of(key)
        @structures ||= Hash.new do |cache, syllable_key|
          parsed = Acoustic::Syllables.parse_key(syllable_key)
          cache[syllable_key] = parsed ? Acoustic::Syllables.structure(parsed[0]) : {}
        end

        @structures[key]
      end
    end
  end
end
