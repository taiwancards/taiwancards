# frozen_string_literal: true

module Huayu
  class SenseImporter
    SOURCE_SLUG = "moe_concised"

    def initialize(path: nil, io: $stdout)
      @path = path || Rails.root.join("dict_and_corpora/corpora/concised.json")
      @io = io
    end

    def call
      source = ContentSource.find_by!(slug: SOURCE_SLUG)
      entries = JSON.parse(File.read(@path))
      by_text = entries.group_by { |entry| entry["word"] }

      stats = {lexemes: 0, senses: 0, sentences: 0, collocations: 0, readings: 0}

      Lexeme.where(kind: %i[word character]).find_each do |lexeme|
        found = by_text[lexeme.text]
        next if found.nil?

        import_entry(lexeme, ordered_for(lexeme, found), source, stats)
      end

      report(stats)
      stats
    end

    private

    def ordered_for(lexeme, entries)
      return entries if entries.size < 2

      known = lexeme.reading_set.map { |reading| zhuyin(reading["zhuyin"]) }
      entries.sort_by.with_index do |entry, index|
        [known.index(zhuyin(entry["zhuyin"])) || known.size, index]
      end
    end

    def zhuyin(value)
      value.to_s.gsub(/[[:space:]　]/, "")
    end

    def import_entry(lexeme, entries, source, stats)
      lexeme.senses.destroy_all
      stats[:lexemes] += 1
      stats[:readings] += 1 if entries.size > 1
      position = 0

      entries.each do |entry|
        reading = entries.size > 1 ? entry["pinyin"].presence : nil

        entry["senses"].each do |raw|
          sense = lexeme.senses.create!(
            position: position,
            reading: reading,
            gloss_zh: raw["definition"].presence,
            content_source: source
          )
          position += 1
          stats[:senses] += 1

          add_examples(sense, raw["sentences"], :sentence, source, stats)
          add_examples(sense, raw["collocations"], :collocation, source, stats)
        end
      end
    end

    def add_examples(sense, texts, kind, source, stats)
      Array(texts).each_with_index do |text, index|
        offset = kind == :collocation ? sense.examples.size : 0
        sense.examples.create!(
          text: text,
          kind: kind,
          position: offset + index,
          content_source: source
        )
        stats[kind == :sentence ? :sentences : :collocations] += 1
      end
    end

    def report(stats)
      @io.puts(format("lexemes with senses : %6d", stats[:lexemes]))
      @io.puts(format("senses             : %6d", stats[:senses]))
      @io.puts(format("sentences          : %6d", stats[:sentences]))
      @io.puts(format("collocations           : %6d", stats[:collocations]))
    end
  end
end
