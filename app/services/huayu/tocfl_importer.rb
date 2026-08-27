# frozen_string_literal: true

require "csv"

module Huayu
  class TocflImporter
    PATH = AppData.path("huayu/tocfl.csv")
    HAN = /\A\p{Han}+\z/

    LEVELS = [
      {tag: "Novice1", name: "TOCFL Novice 1", cefr: "pre-A1"},
      {tag: "Novice2", name: "TOCFL Novice 2", cefr: "pre-A1"},
      {tag: "A1", name: "TOCFL Band A · A1", cefr: "A1"},
      {tag: "A2", name: "TOCFL Band A · A2", cefr: "A2"},
      {tag: "B1", name: "TOCFL Band B · B1", cefr: "B1"},
      {tag: "B2", name: "TOCFL Band B · B2", cefr: "B2"},
      {tag: "C", name: "TOCFL Band C", cefr: "C1-C2"}
    ].freeze

    def initialize(path: PATH)
      @path = Pathname(path)
      @collections = {}
    end

    def call
      counts = Hash.new(0)
      CSV.foreach(@path, headers: true) do |row|
        tag = level_for(row["ID"])
        next if tag.nil?

        forms(row).each do |text, pinyin|
          lexeme = upsert(row, tag, text, pinyin)
          collection_for(tag).add_lexeme(lexeme)
          counts[tag] += 1
        end
      end

      counts
    end

    private

    def forms(row)
      variants = parse_variants(row["Variants"])
      return taiwanese(variants) if variants.any?

      pinyin = row["Pinyin"].to_s.strip
      plain = row["Traditional"]
        .to_s
        .split(%r{[/／]})
        .filter_map { |form| form.strip.presence }
        .select { |form| form.match?(HAN) }
        .map { |form| [form, pinyin] }

      taiwanese(plain)
    end

    def taiwanese(pairs)
      pairs.reject { |form, _pinyin| ChinaGuard.marker?(form) }
    end

    def parse_variants(raw)
      return [] if raw.blank?

      JSON
        .parse(raw)
        .filter_map { |entry| [entry["Traditional"].to_s.strip, entry["Pinyin"].to_s.strip] }
        .select { |form, _pinyin| form.present? && form.match?(HAN) }
    rescue JSON::ParserError
      []
    end

    def level_for(id)
      prefix, index = id.to_s.split("-")
      case prefix
      when "L0"
        index.to_s.start_with?("1") ? "Novice1" : "Novice2"
      when "L1"
        "A1"
      when "L2"
        "A2"
      when "L3"
        "B1"
      when "L4"
        "B2"
      when "L5"
        "C"
      end
    end

    # A form can appear on several lists: 好 is on Novice 1 as hǎo and on Band B as hào, 來 on three
    # of them. The level that belongs on the lexeme is the lowest one — where a learner first meets
    # the form — so a later, harder row must not overwrite it.
    def upsert(row, tag, text, pinyin)
      kind = text.length == 1 && text.match?(HAN) ? :character : :word

      lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[kind], text:)
      lexeme.readings = reading(pinyin) if lexeme.readings["pinyin"].blank? && pinyin.present?
      lexeme.data = lexeme.data.merge("pos" => row["POS"].presence, "tocfl_level" => lowest(lexeme, tag)).compact
      lexeme.add_source("TOCFL #{tag}")
      lexeme.save! if lexeme.changed?
      lexeme
    end

    def lowest(lexeme, tag)
      known = lexeme.data["tocfl_level"]
      return tag if known.blank?

      [known, tag].min_by { |value| LEVELS.index { |level| level[:tag] == value } || LEVELS.length }
    end

    def reading(pinyin)
      {"pinyin" => pinyin, "zhuyin" => Huayu::Zhuyin.from_pinyin(pinyin)}.compact_blank
    end

    def collection_for(tag)
      @collections[tag] ||= begin
        level = LEVELS.find { |entry| entry[:tag] == tag }
        Collection.find_or_create_by!(name: level[:name]) do |collection|
          collection.kind = :tocfl
          collection.level_tag = tag
          collection.position = LEVELS.index(level)
        end
      end
    end
  end
end
