# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class DrillsBuilder
      PATH = "drills.json"
      CRITERIA = "lists: self>=80, top1>=80%, margin>=5; pairs: both members self>=80, " \
        "the pair told apart >=70% on held-out corpus tokens, and the contrast told apart " \
        ">=62% on speakers no template was built from, which is the gap between the weakest " \
        "aspiration pair and the strongest sibilant one; the measured share is the section's decided field"
      DECIDABLE = 70.0
      FAMILY_FLOOR = 62.0
      ON_A_STRANGER = {"aspiration" => 79.8, "sibilant" => 63.9, "coda" => 59.1}.freeze

      GOOD_SELF = 80
      GOOD_TOP1 = 80.0
      GOOD_MARGIN = 5
      BEST_SELF = 85
      BEST_MARGIN = 10

      PAIR_LIMIT = 24
      CODA_LIMIT = 20
      LIST_LIMIT = 30
      VOWEL_LIMIT = 20
      THIN = 5

      INITIAL_GROUPS = {
        "plosive" => {ru: "Взрывные ㄅㄆㄉㄊㄍㄎ", en: "Plosives", initials: %w[b p d t g k]},
        "affricate" => {ru: "Аффрикаты ㄗㄘㄓㄔㄐㄑ", en: "Affricates", initials: %w[z c zh ch j q]},
        "fricative" => {ru: "Фрикативные ㄈㄙㄕㄒㄏ", en: "Fricatives", initials: %w[f s sh x h]},
        "nasal_lateral" => {
          ru: "Носовые и боковые ㄇㄋㄌ",
          en: "Nasals and laterals",
          initials: %w[m n l]
        }
      }.freeze

      def initialize(quality: nil, contrasts: nil, store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
        @quality = quality || read_quality
        @contrasts = contrasts || read_contrasts
      end

      def call
        {
          "generated_at" => Time.current.utc.iso8601,
          "criteria" => CRITERIA,
          "pool" => {"good" => good.length, "best" => best.length, "measured" => @quality.length},
          "sections" => sections.each { |section| annotate(section) }
        }
      end

      def write!
        payload = call
        File.write(File.join(@store.root, PATH), JSON.pretty_generate(payload))
        @io&.puts("usable syllables: #{good.length}, excellent: #{best.length}")
        payload
      end

      private

      def read_quality
        path = File.join(@store.root, SyllableQuality::PATH)
        raise "#{path} is missing — run rake pronunciation:syllable_quality first" unless File.exist?(path)

        JSON.parse(File.read(path))
      end

      def read_contrasts
        path = File.join(@store.root, ContrastQuality::PATH)
        raise "#{path} is missing — run rake pronunciation:contrast_quality first" unless File.exist?(path)

        JSON.parse(File.read(path))["pairs"]
      end

      def sound_enough(key)
        row = @quality.find { |candidate| candidate["key"] == key }
        row && row["self"].to_i >= GOOD_SELF
      end

      def decidable(family)
        return [] if ON_A_STRANGER.fetch(family, 0.0) < FAMILY_FLOOR

        @decidable ||= {}
        @decidable[family] ||= @contrasts
          .select { |pair| pair["family"] == family && pair["accuracy"].to_f >= DECIDABLE }
          .select { |pair| pair["keys"].all? { |key| sound_enough(key) } }
          .sort_by { |pair| -pair["accuracy"].to_f }
      end

      def good
        @good ||= @quality.select do |row|
          row["self"].to_i >= GOOD_SELF && row["top1"].to_f >= GOOD_TOP1 && row["margin"].to_i >= GOOD_MARGIN
        end
      end

      def best
        @best ||= @quality.select do |row|
          row["self"].to_i >= BEST_SELF && row["top1"].to_f == 100.0 && row["margin"].to_i >= BEST_MARGIN
        end
      end

      def by_key = @by_key ||= good.to_h { |row| [row["key"], row] }

      def parse(key) = Acoustic::Syllables.parse_key(key)

      def structure(key)
        parsed = parse(key)
        parsed && Acoustic::Syllables.structure(parsed[0])
      end

      def rank(key)
        row = by_key[key]
        row ? row["self"].to_i + row["margin"].to_i : -1
      end

      def sections
        [aspiration, sibilants] + codas + [tones] + per_tone + initial_groups + vowels
      end

      def aspiration
        {
          "id" => "aspiration",
          "title" => {"ru" => "Придыхание", "en" => "Aspiration"},
          "hint" => {
            "ru" => "ㄍ/ㄎ, ㄅ/ㄆ, ㄉ/ㄊ, ㄐ/ㄑ — разница только в выдохе",
            "en" => "the only difference is the puff of air"
          },
          "kind" => "pair",
          "decided" => ON_A_STRANGER["aspiration"],
          "pairs" => decidable("aspiration").first(PAIR_LIMIT).map { |pair| pair["keys"] }
        }
      end

      def sibilants
        {
          "id" => "sibilants",
          "title" => {"ru" => "Шипящие: ㄓㄔㄕ / ㄗㄘㄙ / ㄐㄑㄒ", "en" => "Sibilant series"},
          "hint" => {
            "ru" => "Ретрофлексные, дентальные и палатальные ряды",
            "en" => "Retroflex, dental and palatal series"
          },
          "kind" => "pair",
          "decided" => ON_A_STRANGER["sibilant"],
          "pairs" => decidable("sibilant").first(PAIR_LIMIT).map { |pair| pair["keys"] }
        }
      end

      def codas
        %w[a e].filter_map do |nucleus|
          picked = decidable("coda").select { |pair| pair["nucleus"] == nucleus }
          next if picked.empty?

          coda_section(nucleus, picked)
        end
      end

      def coda_section(nucleus, picked)
        {
          "id" => "coda_#{nucleus}",
          "title" => {"ru" => "-#{nucleus}n против -#{nucleus}ng", "en" => "-#{nucleus}n vs -#{nucleus}ng"},
          "hint" => {
            "ru" => nucleus == "e" ? "В Тайване feng звучит ближе к «фонг»" : "Передний /a/ против заднего",
            "en" => nucleus == "e" ? "In Taiwan feng leans toward [fong]" : "Front /a/ versus back"
          },
          "kind" => "pair",
          "decided" => ON_A_STRANGER["coda"],
          "pairs" => picked.first(CODA_LIMIT).map { |pair| pair["keys"] }
        }
      end

      def tones
        grouped = Hash.new { |hash, syllable| hash[syllable] = [] }
        by_key.each_key { |key| grouped[parse(key)[0]] << key }

        sets = grouped
          .select { |_, keys| keys.length >= 3 }
          .sort_by { |_, keys| -keys.sum { |key| rank(key) } }
          .first(PAIR_LIMIT)
          .map { |_, keys| keys.sort_by { |key| parse(key)[1] } }

        {
          "id" => "tones",
          "title" => {"ru" => "Тоны на одном слоге", "en" => "Tones on one syllable"},
          "hint" => {
            "ru" => "Один слог во всех тонах — слышно только мелодию",
            "en" => "One syllable across tones — only the melody changes"
          },
          "kind" => "set",
          "sets" => sets
        }
      end

      def per_tone
        (1..5).filter_map do |tone|
          keys = by_key.keys.select { |key| parse(key)[1] == tone }.sort_by { |key| -rank(key) }
          next if keys.length < THIN

          {
            "id" => "tone_#{tone}",
            "title" => {"ru" => "Тон #{tone}", "en" => "Tone #{tone}"},
            "kind" => "list",
            "keys" => keys.first(LIST_LIMIT)
          }
        end
      end

      def initial_groups
        INITIAL_GROUPS.filter_map do |id, spec|
          keys = by_key.keys.select { |key| spec[:initials].include?(structure(key)&.fetch(:initial, nil)) }
          next if keys.length < THIN

          {
            "id" => "initials_#{id}",
            "title" => {"ru" => spec[:ru], "en" => spec[:en]},
            "kind" => "list",
            "keys" => keys.sort_by { |key| -rank(key) }.first(LIST_LIMIT)
          }
        end
      end

      def vowels
        %w[a o e i u v].filter_map do |nucleus|
          keys = by_key.keys.select { |key| structure(key)&.fetch(:nucleus, nil) == nucleus }
          next if keys.length < THIN

          {
            "id" => "vowel_#{nucleus}",
            "title" => {"ru" => "Гласный #{nucleus}", "en" => "Vowel #{nucleus}"},
            "kind" => "list",
            "keys" => keys.sort_by { |key| -rank(key) }.first(VOWEL_LIMIT)
          }
        end
      end

      def annotate(section)
        items = section["pairs"] || section["sets"] || section["keys"] || []
        keys = items.flatten.uniq
        selves = keys.filter_map { |key| by_key[key]&.fetch("self", nil) }

        section["n_items"] = items.length
        section["thin"] = items.length < THIN
        section["n_keys"] = keys.length
        section["median_self"] = selves.empty? ? nil : selves.sort[selves.length / 2]
      end
    end
  end
end
