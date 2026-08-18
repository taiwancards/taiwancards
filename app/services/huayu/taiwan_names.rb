# frozen_string_literal: true

module Huayu
  class TaiwanNames
    DATA = JsonData.new("huayu/taiwan_names.json", default: {}, watch: true)
    SOURCE_SLUG = "wikidata_people"
    SURNAME_SOURCE_SLUG = "moi_names"
    FIELDS = %w[light virtue wisdom strength nature prosperity peace aspiration].freeze
    POSITIONS = %w[any first second].freeze
    COHORTS = %w[elder middle young recent].freeze
    TOP_SURNAMES = 40
    PER_PAGE = 120

    Surname = Data.define(:text, :count, :rank, :share, :young_share, :zhuyin, :pinyin) do
      def percent = (share * 100).round(2)

      def young_percent = (young_share * 100).round(2)

      def rising? = young_share > share
    end

    Character = Data.define(
      :text,
      :first,
      :second,
      :count,
      :zhuyin,
      :pinyin,
      :tone,
      :strokes,
      :en,
      :ru,
      :fields,
      :cohorts,
      :lean
    ) do
      def leans_male? = lean && lean > 0.65

      def leans_female? = lean && lean < 0.35

      def per_mille(cohort) = cohorts[cohort].to_f

      def meaning(locale) = locale.to_s == "ru" ? (ru || en) : en

      def leans = first == second ? "any" : (first > second ? "first" : "second")

      def share_first = count.zero? ? 0 : (first.to_f / count)
    end

    Pair = Data.define(:text, :count, :pmi)

    class << self
      def available? = surnames.any?

      def meta = DATA.value["meta"] || {}

      def source = ContentSource.find_by(slug: SOURCE_SLUG)

      def surname_source = ContentSource.find_by(slug: SURNAME_SOURCE_SLUG)

      def surnames(limit: TOP_SURNAMES) = all_surnames.first(limit)

      def all_surnames
        @all_surnames ||= Array(DATA.value["surnames"]).map do |row|
          Surname.new(
            text: row["text"],
            count: row["count"].to_i,
            rank: row["rank"].to_i,
            share: row["share"].to_f,
            young_share: row["young_share"].to_f,
            zhuyin: row["zhuyin"],
            pinyin: row["pinyin"]
          )
        end
      end

      def characters
        @characters ||= Array(DATA.value["characters"]).map do |row|
          Character.new(
            text: row["text"],
            first: row["first"].to_i,
            second: row["second"].to_i,
            count: row["count"].to_i,
            zhuyin: row["zhuyin"],
            pinyin: row["pinyin"],
            tone: row["tone"],
            strokes: row["strokes"],
            en: row["en"],
            ru: row["ru"],
            fields: Array(row["fields"]),
            cohorts: (row["cohorts"] || {}),
            lean: row["lean"]
          )
        end
      end

      def pairs
        @pairs ||= Array(DATA.value["pairs"]).map do |row|
          Pair.new(text: row["text"], count: row["count"].to_i, pmi: row["pmi"].to_f)
        end
      end

      def filter(field: nil, position: nil, tone: nil, cohort: nil, limit: PER_PAGE)
        rows = characters
        rows = rows.select { |row| row.fields.include?(field) } if FIELDS.include?(field)
        rows = rows.select { |row| row.leans == position } if %w[first second].include?(position)
        rows = rows.select { |row| row.tone == tone.to_i } if tone.present?

        if COHORTS.include?(cohort)
          rows = rows.select { |row| row.per_mille(cohort).positive? }.sort_by { |row| -row.per_mille(cohort) }
        end

        rows.first(limit)
      end

      def cohort_sizes = meta["cohorts"] || {}

      def contours = Array(DATA.value["contours"])

      def assistant_payload
        {
          surnames: all_surnames.first(120).map { |row|
            {text: row.text, pinyin: row.pinyin, zhuyin: row.zhuyin, share: row.share}
          },
          characters: Array(DATA.value["characters"]).map { |row|
            row.slice(
              "text",
              "first",
              "second",
              "pinyin",
              "zhuyin",
              "tone",
              "strokes",
              "en",
              "ru",
              "fields",
              "lean",
              "cohorts"
            )
          },
          pairs: Array(DATA.value["pairs"]).map { |row| row.slice("text", "pmi") },
          contours: contours,
          meta: meta
        }
      end

      def partners(text, limit: 8)
        pairs.select { |pair| pair.text.include?(text.to_s) }.max_by(limit, &:pmi)
      end

      def field_counts
        @field_counts ||= FIELDS.index_with { |field| characters.count { |row| row.fields.include?(field) } }
      end

      def reset!
        DATA.reset!
        %i[@all_surnames @characters @pairs @field_counts].each do |name|
          remove_instance_variable(name) if instance_variable_defined?(name)
        end
      end
    end
  end
end
