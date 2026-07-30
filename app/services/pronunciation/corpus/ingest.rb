# frozen_string_literal: true

require "json"
require "fileutils"

module Pronunciation
  module Corpus
    class Ingest
      MIN_SPAN_MS = 90.0
      MIN_AUDIO_S = 0.12

      def initialize(only: nil, manifest: Manifest.new, out: nil, io: nil)
        @only = only && Array(only).to_set
        @manifest = manifest
        @out = out || Tokens.root
        @io = io
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
        @io&.puts("  keys written: #{keys.length}")
        keys
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

        samples, rate = Acoustic::Dsp.read_wav(@manifest.resolve(relative))
        return [] if samples.length < rate * MIN_AUDIO_S

        analysis = Acoustic::Features.analyze(samples, rate)
        spans = Acoustic::Features.syllable_spans(analysis, tokens.first["n_syllables"])
        return [] if spans.nil?

        wanted.filter_map { |token| row(analysis, spans, token, relative) }
      rescue StandardError
        []
      end

      def row(analysis, spans, token, relative)
        span = spans[token["index"]]
        return nil if span.nil?
        return nil if (span[1] - span[0]) * Acoustic::Features::HOP_MS < MIN_SPAN_MS

        Acoustic::Features
          .extract(
            analysis,
            span,
            initial: initial_of(token["_key"]),
            utterance_initial: token["index"].to_i.zero?
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

      def initial_of(key)
        @initials ||= Hash.new do |cache, syllable_key|
          parsed = Acoustic::Syllables.parse_key(syllable_key)
          cache[syllable_key] = parsed && Acoustic::Syllables.structure(parsed[0])[:initial]
        end

        @initials[key]
      end
    end
  end
end
