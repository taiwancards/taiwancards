# frozen_string_literal: true

module Huayu
  class SentenceWordLinker
    LIMIT = 50
    PAGE = 5_000
    SLACK = 2
    MASK = (1 << 32) - 1

    def initialize(io: $stdout, limit: LIMIT, quality: ExampleQuality.instance)
      @io = io
      @limit = limit
      @quality = quality
    end

    def call
      SentenceWord.delete_all

      word_ids = Lexeme.where(kind: %i[word character collocation]).pluck(:text, :id).to_h
      best = Hash.new { |memo, key| memo[key] = [] }
      scanned = 0

      each_page do |rows|
        rows.each do |id, text, data|
          scanned += 1
          collect(id, text, data, word_ids, best)
        end
      end

      written = persist(best)
      @io.puts(format("sentences scanned    : %8d", scanned))
      @io.puts(format("examples recorded    : %8d", written))
      @io.puts(format("words with examples  : %8d", best.size))
      @io.puts(format("cap per word         : %8d", @limit))
      written
    end

    private

    def each_page
      scope = Lexeme.where(kind: :sentence).order(:id)
      cursor = 0

      loop do
        rows = scope.where(id: cursor..).limit(PAGE).pluck(:id, :text, :data)
        break if rows.empty?

        yield(rows)
        cursor = rows.last.first + 1
      end
    end

    def collect(id, text, data, word_ids, best)
      segments = Array(data["segments"])
      difficulty = data["difficulty"].to_i
      taiwan = data["taiwan"].to_i
      audio = data.key?("audio")
      units = segments.flat_map { |unit| word_ids.key?(unit) ? [unit] : unit.chars }.uniq

      units.each do |unit|
        lexeme_id = word_ids[unit]
        next if lexeme_id.nil?

        gdex = @quality.call(text:, segments:, target: unit, difficulty:, taiwan:, audio:)
        next if gdex.zero?

        bucket = best[lexeme_id]
        bucket << [id, gdex]
        prune(bucket) if bucket.length > @limit * SLACK
      end
    end

    def prune(bucket)
      bucket.sort_by! { |(id, gdex)| [-gdex, id] }
      bucket.slice!(@limit..)
    end

    def persist(best)
      written = 0
      buffer = []

      best.each do |lexeme_id, bucket|
        prune(bucket)
        bucket.each { |sentence_id, gdex| buffer << {sentence_id:, lexeme_id:, gdex:} }
        next if buffer.length < PAGE

        written += flush(buffer)
        buffer = []
      end

      written + flush(buffer)
    end

    def flush(rows)
      return 0 if rows.empty?

      SentenceWord.insert_all(rows, unique_by: :index_sentence_words_unique)
      rows.length
    end
  end
end
