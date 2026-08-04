# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class DrillsBuilder
      PATH = "drills.json"
      CRITERIA = "self>=80, top1>=80%, margin>=5"

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

      SERIES = {
        "retroflex" => %w[zh ch sh r],
        "dental" => %w[z c s],
        "alveolo_palatal" => %w[j q x]
      }.freeze

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

      def initialize(quality: nil, store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
        @quality = quality || read_quality
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
          "pairs" => partner_pairs(Acoustic::Phonology::ASPIRATION_PAIRS).first(PAIR_LIMIT)
        }
      end

      def partner_pairs(map)
        found = []

        by_key.each_key do |key|
          st = structure(key)
          next if st.nil?

          other = map[st[:initial]]
          next if other.nil?

          partner = "#{other}#{st[:final]}#{parse(key)[1]}"
          next unless by_key.key?(partner)
          next if found.any? { |pair| pair.include?(key) }

          found << [key, partner].sort
        end

        found.sort_by { |pair| -(rank(pair[0]) + rank(pair[1])) }
      end

      def sibilants
        pairs = []

        by_key.each_key do |key|
          st = structure(key)
          next if st.nil? || st[:sibilant].nil?

          index = SERIES[st[:sibilant].to_s]&.index(st[:initial])
          next if index.nil?

          SERIES.each do |name, list|
            next if name == st[:sibilant].to_s || list[index].nil?

            partner = "#{list[index]}#{st[:final]}#{parse(key)[1]}"
            next unless by_key.key?(partner)

            pair = [key, partner].sort
            pairs << pair unless pairs.include?(pair)
          end
        end

        {
          "id" => "sibilants",
          "title" => {"ru" => "Шипящие: ㄓㄔㄕ / ㄗㄘㄙ / ㄐㄑㄒ", "en" => "Sibilant series"},
          "hint" => {
            "ru" => "Ретрофлексные, дентальные и палатальные ряды",
            "en" => "Retroflex, dental and palatal series"
          },
          "kind" => "pair",
          "pairs" => pairs.sort_by { |pair| -(rank(pair[0]) + rank(pair[1])) }.first(PAIR_LIMIT)
        }
      end

      def codas
        found = by_key.each_key.filter_map do |key|
          st = structure(key)
          next if st.nil? || st[:coda] != "n"

          partner = "#{st[:initial]}#{st[:medial]}#{st[:nucleus]}ng#{parse(key)[1]}"
          next unless by_key.key?(partner)

          {keys: [key, partner], nucleus: st[:nucleus]}
        end

        %w[a e].filter_map do |nucleus|
          picked = found.select { |pair| pair[:nucleus] == nucleus }
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
          "pairs" => picked
            .sort_by { |pair| -(rank(pair[:keys][0]) + rank(pair[:keys][1])) }
            .first(CODA_LIMIT)
            .map { |pair| pair[:keys] }
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
