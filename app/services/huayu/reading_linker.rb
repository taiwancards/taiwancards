# frozen_string_literal: true

module Huayu
  class ReadingLinker
    CEDICT = "dictionaries/cedict.json"
    CONCISED = "corpora/concised.json"
    BATCH = 5_000

    def initialize(io: $stdout, cedict: nil, concised: nil)
      @io = io
      @cedict_path = Pathname(cedict || AppData.path(CEDICT))
      @concised_path = Pathname(concised || AppData.path(CONCISED))
    end

    def drift? = unlinked.exists?

    def call
      @readings = character_readings
      @cedict = cedict_syllables
      @examples = moe_examples
      stats = Hash.new(0)
      pending = Hash.new { |all, reading| all[reading] = [] }
      queued = 0

      rows.find_each(batch_size: BATCH) do |row|
        reading = resolve(row, stats)
        if reading.blank?
          stats[:unresolved] += 1
          next unless disowned?(row)

          stats[:cleared] += 1
        end

        pending[reading] << row.id
        queued += 1
        next if queued < BATCH

        flush(pending)
        queued = 0
      end

      flush(pending)
      report(stats)
      stats
    end

    private

    def disowned?(row)
      return false if row.stored.blank?

      @readings[row.child_text].to_a.none? { |one| one["pinyin"] == row.stored }
    end

    def unlinked
      rows
        .where(reading: nil)
        .where("coalesce(jsonb_array_length(child.data -> 'readings'), 1) = 1")
        .where("child.readings <> '{}'::jsonb OR child.data -> 'readings' <> '[]'::jsonb")
    end

    def rows
      LexemeLink
        .joins("JOIN lexemes parent ON parent.id = lexeme_links.parent_id")
        .joins("JOIN lexemes child ON child.id = lexeme_links.child_id")
        .where("child.kind = ?", Lexeme.kinds.fetch("character"))
        .where("parent.kind IN (?)", Lexeme.kinds.values_at("word", "collocation"))
        .select(
          "lexeme_links.id",
          "lexeme_links.position",
          "lexeme_links.reading AS stored",
          "child.text AS child_text",
          "parent.text AS parent_text",
          "parent.readings AS parent_readings"
        )
    end

    def resolve(row, stats)
      listed = @readings[row.child_text]
      return nil if listed.blank?

      if listed.size == 1
        stats[:single] += 1
        return listed.first["pinyin"]
      end

      from_zhuyin(row, listed, stats) ||
        from_pinyin(row, listed, stats) ||
        from_examples(row, listed, stats)
    end

    def from_zhuyin(row, listed, stats)
      syllable = zhuyin_syllable(row)
      found = syllable && match(listed, syllable, :zhuyin)
      return nil if found.blank?

      stats[:zhuyin] += 1
      found
    end

    def from_pinyin(row, listed, stats)
      syllable = pinyin_syllable(row)
      found = syllable && match(listed, syllable, :pinyin)
      return nil if found.blank?

      stats[:pinyin] += 1
      found
    end

    def from_examples(row, listed, stats)
      found = @examples[[row.child_text, row.parent_text]]
      return nil if found.blank?
      return nil if listed.none? { |one| one["pinyin"] == found }

      stats[:examples] += 1
      found
    end

    def zhuyin_syllable(row)
      syllable_at(row, parent_readings(row)["zhuyin"].to_s.split(/[[:space:]　]+/))
    end

    def pinyin_syllable(row)
      syllable_at(row, @cedict[row.parent_text].to_a)
    end

    def syllable_at(row, syllables)
      syllables.size == row.parent_text.chars.size ? syllables[row.position].presence : nil
    end

    def parent_readings(row)
      value = row.parent_readings
      return value if value.is_a?(Hash)

      JSON.parse(value.to_s.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def match(listed, syllable, system)
      wanted = normalize(syllable, system)
      exact = listed.find { |one| normalize(one[system.to_s], system) == wanted }
      return exact["pinyin"] if exact

      bare = strip_tone(wanted, system)
      same = listed.select { |one| strip_tone(normalize(one[system.to_s], system), system) == bare }
      same.size == 1 ? same.first["pinyin"] : nil
    end

    def normalize(value, system)
      text = value.to_s.gsub(/[[:space:]　]/, "")
      system == :pinyin ? text.downcase : text
    end

    ZHUYIN_TONES = /[ˊˇˋ˙]/

    def strip_tone(value, system)
      return value.gsub(ZHUYIN_TONES, "") if system == :zhuyin

      value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").unicode_normalize(:nfc)
    end

    def character_readings
      Lexeme
        .where(kind: :character)
        .pluck(:text, :data, :readings)
        .to_h { |text, data, readings| [text, (data["readings"].presence || [readings]).compact_blank] }
    end

    def cedict_syllables
      return {} unless @cedict_path.exist?

      JSON
        .parse(@cedict_path.read)
        .transform_values { |entry| entry["pinyin"].to_s.split(/\s+/) }
        .reject { |_text, syllables| syllables.empty? }
    end

    def moe_examples
      return {} unless @concised_path.exist?

      JSON.parse(@concised_path.read).each_with_object({}) do |entry, all|
        text = entry["word"].to_s
        next unless text.chars.size == 1

        entry["senses"].to_a.each do |sense|
          sense["collocations"].to_a.each do |example|
            all[[text, example]] ||= entry["pinyin"]
          end
        end
      end
    end

    def flush(pending)
      pending.each do |reading, ids|
        ids.each_slice(BATCH) { |slice| LexemeLink.where(id: slice).update_all(reading: reading) }
      end

      pending.clear
    end

    def report(stats)
      @io.puts(format("single reading: %6d", stats[:single]))
      @io.puts(format("by word zhuyin        : %6d", stats[:zhuyin]))
      @io.puts(format("by CC-CEDICT pinyin   : %6d", stats[:pinyin]))
      @io.puts(format("by dictionary examples    : %6d", stats[:examples]))
      @io.puts(format("unresolved        : %6d", stats[:unresolved]))
      @io.puts(format("cleared, the character dropped that reading : %6d", stats[:cleared]))
    end
  end
end
