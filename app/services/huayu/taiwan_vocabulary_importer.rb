# frozen_string_literal: true

module Huayu
  class TaiwanVocabularyImporter
    SOURCE_SLUG = "wiktionary"

    def initialize(path: nil, io: $stdout)
      @path = Pathname(path || Rails.root.join("dict_and_corpora/corpora/taiwan_wiktionary.json"))
      @io = io
    end

    def call
      unless @path.exist?
        @io.puts("no Taiwanese vocabulary file: #{@path}")
        return 0
      end

      source = ContentSource.find_by(slug: SOURCE_SLUG)
      unless source&.carries_content?
        @io.puts(
          "source #{SOURCE_SLUG} is disabled or unregistered, skipping"
        )
        return 0
      end

      entries = JSON.parse(@path.read)
      existing = Lexeme.where(kind: %i[word collocation character]).pluck(:text).to_set

      added = 0
      marked = 0

      entries.each_slice(500) do |slice|
        ActiveRecord::Base.transaction do
          slice.each do |text, info|
            if existing.include?(text)
              marked += 1 if mark_existing(text)
              next
            end

            added += 1 if create(text, info)
          end
        end
      end

      @io.puts(
        format(
          "Taiwanese vocabulary added: %5d, existing marked: %5d",
          added,
          marked
        )
      )
      TextAnalyzer.reset_vocabulary!
      added
    end

    private

    def mark_existing(text)
      lexeme = Lexeme.find_by(text: text)
      return false if lexeme.nil? || lexeme.data["taiwan_specific"]

      lexeme.update_column(:data, lexeme.data.merge("taiwan_specific" => true))
      true
    end

    def create(text, info)
      kind = text.length == 1 ? :character : :word
      lexeme = Lexeme.create!(
        kind: kind,
        text: text,
        meanings: {"en" => info["gloss"].to_s.strip}.compact_blank,
        data: {
          "taiwan_specific" => true,
          "etymology_text" => EtymologyText.normalize(info["etymology"]).presence
        }.compact
      )
      lexeme.present?
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      false
    end
  end
end
