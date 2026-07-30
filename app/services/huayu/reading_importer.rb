# frozen_string_literal: true

module Huayu
  class ReadingImporter
    CONCISED = "corpora/concised.json"
    REVISED = "corpora/moedict/dict-revised.json"
    KINDS = %i[character word collocation].freeze

    def initialize(io: $stdout, concised: nil, revised: nil)
      @io = io
      @concised_path = Pathname(concised || AppData.path(CONCISED))
      @revised_path = Pathname(revised || AppData.path(REVISED))
    end

    def call
      @concised = concised
      @revised = revised
      stats = {written: 0, several: 0, voiced: 0, replaced: 0}

      Lexeme.where(kind: KINDS).find_each do |lexeme|
        readings = readings_for(lexeme, stats)
        next if readings.blank? || readings == lexeme.reading_set

        lexeme.data = lexeme.data.merge("readings" => readings)
        lexeme.readings = readings.first
        lexeme.save!
        stats[:written] += 1
        stats[:several] += 1 if readings.size > 1
      end

      report(stats)
      stats
    end

    private

    def readings_for(lexeme, stats)
      official = @concised[lexeme.text]
      listed = official || @revised[lexeme.text] || []
      voiced = lexeme.character? ? audio_readings(lexeme.text) : []
      stats[:voiced] += 1 if listed.any? && voiced.any? { |one| !known?(listed, one) }
      merged = merge(listed, voiced)
      return [] if merged.empty?

      canonical = lexeme.reading_set.first
      return merged if canonical.blank?

      mine, rest = merged.partition { |one| same?(one, canonical) }
      return mine + rest if mine.any?
      return [canonical] + rest if official.nil?

      stats[:replaced] += 1
      rest
    end

    def merge(listed, voiced)
      voiced.each_with_object(listed.dup) do |one, all|
        all << one unless known?(all, one)
      end
    end

    def known?(readings, one)
      readings.any? { |other| same?(other, one) }
    end

    def same?(one, other)
      zhuyin(one).present? && zhuyin(one) == zhuyin(other)
    end

    def zhuyin(reading)
      reading["zhuyin"].to_s.gsub(/[[:space:]　]/, "")
    end

    def audio_readings(text)
      MoeAudio.readings(text).filter_map { |one| entry(one["pinyin"], one["zhuyin"]) }
    end

    def concised
      group(JSON.parse(@concised_path.read)) do |raw|
        [raw["word"], entry(raw["pinyin"], raw["zhuyin"]), raw["senses"].to_a.size]
      end
    end

    def revised
      group(JSON.parse(@revised_path.read).flat_map { |raw| heteronyms(raw) }, &:itself)
    end

    def heteronyms(raw)
      Array(raw["heteronyms"]).map do |one|
        [raw["title"], entry(one["pinyin"], one["bopomofo"]), Array(one["definitions"]).size]
      end
    end

    def group(rows)
      rows
        .each_with_object({}) do |row, all|
          text, reading, weight = yield(row)
          next if text.blank? || reading.nil?

          (all[text] ||= []) << [reading, weight, all[text].size]
        end
        .transform_values { |list| order(list) }
    end

    def order(list)
      list
        .uniq { |reading, _weight, _position| zhuyin(reading) }
        .sort_by { |_reading, weight, position| [-weight, position] }
        .map(&:first)
    end

    def entry(pinyin, zhuyin)
      reading = {
        "pinyin" => ReadingForms.normalize_zhuyin(pinyin),
        "zhuyin" => ReadingForms.normalize_zhuyin(zhuyin)
      }.compact_blank
      reading["zhuyin"].present? ? reading : nil
    end

    def report(stats)
      @io.puts(format("lexemes with an updated reading : %6d", stats[:written]))
      @io.puts(format("of them with several readings: %6d", stats[:several]))
      @io.puts(format("readings added from audio  : %6d", stats[:voiced]))
      @io.puts(format("reading replaced by the dictionary one : %6d", stats[:replaced]))
    end
  end
end
