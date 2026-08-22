# frozen_string_literal: true

require "json"
require "fileutils"

module Pronunciation
  module Corpus
    class TemplateBuilder
      STYLES = {
        "citation" => TemplateStore::CITATION,
        "word" => "taiwan_word",
        "word_initial" => TemplateStore::WORD_INITIAL,
        "word_medial" => TemplateStore::WORD_MEDIAL,
        "word_final" => TemplateStore::WORD_FINAL
      }.freeze

      MIN_CITATION = 6
      MIN_WORD = 4
      MIN_TOKENS = 2
      CORE_SOURCE = "moe"
      MIN_CORE = 3
      DIGITS = 4

      def initialize(style: "citation", only: nil, out: nil, source: Tokens::TAIWAN, io: nil)
        @style = style
        @only = only && Array(only)
        @source = source
        @out = out || File.join(TemplateStore.instance.root, "templates", STYLES.fetch(style))
        @io = io
      end

      attr_reader :out

      def keys = @only || Tokens.available(@source)

      def call
        FileUtils.mkdir_p(@out)
        built = FanOut.map(keys, io: @io) { |chunk| chunk.filter_map { |key| build(key) } }.flatten(1)
        built.each { |key, template| File.write(File.join(@out, "#{key}.json"), JSON.generate(template)) }
        dropped = forget_stale(built.map(&:first))
        @io&.puts("  templates: #{built.length}#{", stale removed: #{dropped}" if dropped.positive?}")
        built.to_h
      end

      def forget_stale(keys)
        return 0 if @only

        wanted = keys.to_set
        stale = Dir.glob(File.join(@out, "*.json")).reject { |path| wanted.include?(File.basename(path, ".json")) }
        stale.each { |path| File.delete(path) }
        stale.length
      end

      def write_index!(built)
        entries = built.keys.sort.filter_map { |key| index_entry(key, built) }
        path = File.join(File.dirname(@out), "index.json")

        File.write(
          path,
          JSON.generate(
            "built_at" => Time.current.utc.iso8601,
            "norm" => "taiwan",
            "sources" => manifest_sources,
            "keys" => built.transform_values { |t| summary(t) },
            "quiz" => entries
          )
        )

        path
      end

      def build(key)
        every = tokens_for(key)
        rows = core(every)
        return nil if rows.length < MIN_TOKENS

        style, used = choose(rows)
        return nil if used.length < MIN_TOKENS

        meta = used.map { |r|
          {"speaker" => r["_speaker"], "source" => r["_source"], "n_syllables" => r["_n_syllables"]}
        }
        template = Acoustic::Templates.build(
          key,
          used,
          meta,
          variability: variability,
          vot: VotNorms.for_rows(key, every)
        )
        return nil if template.nil?

        template["norm"] = "taiwan"
        template["zhuyin"] = Acoustic::Syllables.zhuyin[key]
        template["provenance"]["style"] = style
        template["provenance"]["n_citation"] = used.count { |r| r["_n_syllables"] == 1 }
        template["provenance"]["n_available"] = rows.length

        [key, round(template)]
      rescue StandardError
        nil
      end

      private

      def tokens_for(key)
        return [] if Acoustic::Syllables.parse_key(key).nil?

        rows = []
        Tokens.each(key, @source, speakers: :fitting) do |row|
          row["f0_register"] = SpeakerPitch.register(row["_speaker"], row["f0_ref_hz"])
          rows << row
        end

        rows
      end

      def core(rows)
        picked = rows.select { |r| source_family(r) == CORE_SOURCE }
        picked.length >= MIN_CORE ? picked : rows
      end

      def source_family(row) = row["_source"].to_s.start_with?("moe") ? "moe" : "textbook"

      def choose(rows)
        citation = rows.select { |r| r["_n_syllables"].to_i == 1 }
        initial = rows.select { |r| connected?(r) && r["_index"].to_i.zero? }
        tail = rows.select { |r| connected?(r) && r["_index"].to_i.positive? }
        final = tail.select { |r| last?(r) }

        case @style
        when "word_initial"
          initial.length >= MIN_WORD ? ["word_initial", initial] : ["wi+citation", initial + citation]
        when "word_medial"
          medial = tail.reject { |row| last?(row) }
          return ["word_medial", medial] if medial.length >= MIN_WORD

          tail.length >= MIN_WORD ? ["wm+tail", tail] : ["wm+word", tail + initial]
        when "word_final"
          return ["word_final", final] if final.length >= MIN_WORD

          tail.length >= MIN_WORD ? ["wf+tail", tail] : ["wf+word", tail + initial]
        when "word"
          both = initial + tail
          both.length >= MIN_CITATION ? ["word", both] : ["word+citation", both + citation]
        else
          citation_style(citation, initial, rows)
        end
      end

      def connected?(row) = row["_n_syllables"].to_i > 1

      def last?(row) = row["_index"].to_i == row["_n_syllables"].to_i - 1

      def citation_style(citation, initial, rows)
        return ["citation", citation] if citation.length >= MIN_CITATION
        return ["citation+word_initial", citation + initial] if (citation + initial).length >= MIN_CITATION

        ["mixed", rows]
      end

      def manifest_sources
        manifest = Manifest.new
        manifest.exist? ? manifest.sources : {}
      end

      def variability
        return @variability if defined?(@variability)

        path = File.join(TemplateStore.instance.root, "variability.json")
        @variability = File.exist?(path) ? JSON.parse(File.read(path))["model"] : nil
      end

      def index_entry(key, built)
        meta = Acoustic::Syllables.inventory[key]
        return nil if meta.nil?

        {
          "key" => key,
          "syllable" => meta["syllable"],
          "tone" => meta["tone"],
          "zhuyin" => Acoustic::Syllables.zhuyin[key] || meta["zhuyin"],
          "chars" => (meta["chars"] if Acoustic::Syllables.described?(key)),
          "confidence" => built[key].dig("provenance", "confidence"),
          "style" => built[key].dig("provenance", "style"),
          "confusions" => Acoustic::Syllables.confusion_set(meta["syllable"], meta["tone"]).select { |k|
            built.key?(k)
          }
        }
      end

      def summary(template)
        {
          "n_tokens" => template.dig("provenance", "n_tokens"),
          "n_citation" => template.dig("provenance", "n_citation"),
          "style" => template.dig("provenance", "style"),
          "confidence" => template.dig("provenance", "confidence"),
          "sources" => template.dig("provenance", "sources")
        }
      end

      def round(value)
        case value
        when Float
          value.round(DIGITS)
        when Hash
          value.transform_values { |nested| round(nested) }
        when Array
          value.map { |nested| round(nested) }
        else
          value
        end
      end
    end
  end
end
