# frozen_string_literal: true

require "csv"

module Collections
  module Import
    class Parser
      SOURCES = %w[pleco anki quizlet].freeze
      MAX_BYTES = 2 * 1024 * 1024
      MAX_ROWS = 3_000

      Row = Data.define(:line, :original, :candidates, :pinyin)
      Result = Data.define(:rows, :skipped, :total, :truncated, :unreadable) do
        def empty? = rows.empty?
      end

      HAN = /\p{Han}/
      BRACKETED = /\A(?<outer>[^\[\]]+)\[(?<inner>[^\[\]]+)\]\z/
      PARENTHESES = /[(（][^)）]*[)）]/
      ALTERNATIVES = /[,;，；、\/／|]/
      KEPT = /[^\p{Han}A-Za-z0-9]/
      TONED = /[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]|[a-zü]\d/i
      PINYIN = /\A[a-zA-Züv:āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ1-5\s'’·-]+\z/
      ANKI_SEPARATORS = {"tab" => "\t", "comma" => ",", "semicolon" => ";", "pipe" => "|", "space" => " "}.freeze
      SOUND = /\[sound:[^\]]*\]/

      def self.call(source, text) = new(source, text).call

      def initialize(source, text)
        @source = source.to_s
        @text = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub.delete_prefix("﻿")
      end

      def call
        if @text.bytesize > MAX_BYTES
          return Result.new(rows: [], skipped: 0, total: 0, truncated: false, unreadable: true)
        end

        records = table
        kept = records.first(MAX_ROWS)
        column = han_column(kept)
        if column.nil?
          return Result.new(rows: [], skipped: kept.size, total: records.size, truncated: false, unreadable: kept.any?)
        end

        reading = pinyin_column(kept, column)
        rows = kept.filter_map { |line, fields| row(line, fields, column, reading) }
        Result.new(
          rows:,
          skipped: kept.size - rows.size,
          total: records.size,
          truncated: records.size > MAX_ROWS,
          unreadable: false
        )
      rescue CSV::MalformedCSVError, ArgumentError
        Result.new(rows: [], skipped: 0, total: 0, truncated: false, unreadable: true)
      end

      private

      def table
        case @source
        when "pleco"
          xml? ? pleco_xml : pleco_text
        when "anki"
          anki
        else
          quizlet
        end
      end

      def numbered(lines)
        lines.each_with_index.filter_map { |fields, index| [index + 1, fields] if fields.any?(&:present?) }
      end

      def pleco_text
        numbered(@text.each_line.map { |line| line.start_with?("//") ? [] : line.chomp.split("\t") })
      end

      def xml? = @text.lstrip.start_with?("<?xml", "<plecoflash")

      def pleco_xml
        require "nokolexbor"

        cards = Nokolexbor::HTML(@text).css("card")
        numbered(cards.map { |card| [pleco_headword(card), card.at_css("pron")&.text.to_s] })
      end

      def pleco_headword(card)
        traditional = card.at_css("headword[charset=tc]")&.text
        simplified = card.at_css("headword[charset=sc]")&.text
        return traditional.to_s if simplified.blank? || traditional == simplified

        "#{simplified}[#{traditional}]"
      end

      def anki
        headers, body = @text.lines.partition { |line| line.start_with?("#") }
        separator = anki_separator(headers)
        rows = CSV.parse(body.join, col_sep: separator, quote_char: "\"", liberal_parsing: true)
        numbered(rows.map { |fields| fields.map(&:to_s) })
      end

      def anki_separator(headers)
        declared = headers.filter_map { |line| line[/\A#separator:(\S+)/, 1] }.first.to_s.downcase
        ANKI_SEPARATORS[declared] || (declared.length == 1 ? declared : "\t")
      end

      def quizlet
        rows = @text.include?("\n") ? @text.lines.map(&:chomp) : @text.split(";")
        separator = rows.any? { |row| row.include?("\t") } ? "\t" : ","
        numbered(rows.map { |row| row.split(separator, 2) })
      end

      def han_column(records)
        widths = records.map { |_, fields| fields.size }.max.to_i
        scores = (0...widths).map { |index| records.count { |_, fields| han?(fields[index]) } }
        best = scores.max.to_i
        best.positive? ? scores.index(best) : nil
      end

      def pinyin_column(records, han)
        widths = records.map { |_, fields| fields.size }.max.to_i
        found = (0...widths).excluding(han).max_by { |index| records.count { |_, fields| pinyin?(fields[index]) } }
        return nil if found.nil?

        records.count { |_, fields| pinyin?(fields[found]) } * 2 > records.size ? found : nil
      end

      def han?(field)
        text = strip(field).gsub(/\s/, "")
        text.present? && text.scan(HAN).size * 2 >= text.length
      end

      def pinyin?(field)
        text = strip(field)
        text.present? && text.match?(PINYIN) && text.match?(TONED)
      end

      def row(line, fields, column, reading)
        raw = strip(fields[column])
        candidates = variants(raw)
        return nil if candidates.empty?

        Row.new(line:, original: raw, candidates:, pinyin: reading && strip(fields[reading]).presence)
      end

      def variants(raw)
        bracketed = raw.gsub(/\s/, "").match(BRACKETED)
        forms = bracketed ? [bracketed[:inner], bracketed[:outer]] : [raw]
        forms.flat_map { |form| spellings(form) }.uniq
      end

      def spellings(form)
        form.gsub(PARENTHESES, "").split(ALTERNATIVES).map { |part| part.gsub(KEPT, "") }.select { |part|
          part.match?(HAN)
        }
      end

      def strip(field)
        text = field.to_s.gsub(SOUND, "")
        text = CGI.unescapeHTML(text.gsub(/<[^>]*>/, " ")) if text.include?("<") || text.include?("&")
        text.tr(" ", " ").strip
      end
    end
  end
end
