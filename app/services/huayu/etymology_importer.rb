# frozen_string_literal: true

module Huayu
  class EtymologyImporter
    SOURCE_SLUG = "wiktionary"

    def initialize(path: nil, io: $stdout)
      @path = Pathname(path || Rails.root.join("dict_and_corpora/corpora/etymology.json"))
      @io = io
    end

    def call
      unless @path.exist?
        @io.puts("no etymology file: #{@path}")
        return 0
      end

      source = ContentSource.find_by(slug: SOURCE_SLUG)
      if source.nil?
        @io.puts("source #{SOURCE_SLUG} is not registered")
        return 0
      end

      unless source.carries_content?
        @io.puts("source #{SOURCE_SLUG} disabled, skipped")
        return 0
      end

      entries = JSON.parse(@path.read)
      applied = 0

      Lexeme
        .where(kind: %i[character word collocation])
        .find_in_batches(batch_size: 500) do |batch|
          batch.each do |lexeme|
            entry = entries[lexeme.text]
            next if entry.nil?

            text = entry["text"].to_s.strip
            next if text.blank?
            next if lexeme.data["etymology_text"] == text

            lexeme.update_column(
              :data,
              lexeme.data.merge("etymology_text" => text, "etymology_source" => source.slug)
            )
            applied += 1
          end
        end

      @io.puts(format("etymologies attached: %d", applied))
      applied
    end
  end
end
