# frozen_string_literal: true

module Huayu
  class ViGlossEnricher
    PATH = AppData.path("huayu/vi_glosses.json")
    LOCALE = "vi"
    OWNED_ELSEWHERE = %i[sentence measure_word radical].freeze

    def initialize(path: PATH, curated: CuratedGlosses.new)
      @path = Pathname(path)
      @curated = curated
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      store = JSON.parse(@path.read)
      glosses = store.fetch("lexemes", {})
      lexemes = fill_lexemes(glosses)
      senses = fill_senses(store.fetch("senses", {}), glosses)
      radicals = fill_radicals(store.fetch("radicals", {}))
      {glosses: glosses.size, lexemes:, senses:, radicals:}
    end

    private

    def scope(texts) = Lexeme.where(text: texts).where.not(kind: OWNED_ELSEWHERE)

    def fill_lexemes(glosses)
      written = 0
      glosses.keys.each_slice(500) do |texts|
        scope(texts).find_each do |lexeme|
          fresh = glosses[lexeme.text].to_s.strip
          next if fresh.empty? || lexeme.meanings[LOCALE] == fresh
          next if owned_by_a_page?(lexeme)

          lexeme.update!(meanings: lexeme.meanings.merge(LOCALE => fresh))
          written += 1
        end
      end

      written
    end

    def fill_senses(by_text, glosses)
      texts = (by_text.keys + glosses.keys).uniq
      ids = scope(texts).pluck(:id, :text).to_h
      senses = LexemeSense.where(lexeme_id: ids.keys).pluck(:id, :lexeme_id, :gloss_zh, :meanings).group_by(&:second)

      rows = senses.flat_map do |lexeme_id, rows_for|
        text = ids[lexeme_id]
        wanted = by_text.fetch(text, {})
        rows_for.filter_map do |id, _lexeme_id, gloss_zh, stored|
          fresh = wanted[gloss_zh].presence || (glosses[text].presence if rows_for.one?)
          next if fresh.blank? || stored[LOCALE] == fresh

          [id, stored.merge(LOCALE => fresh.strip)]
        end
      end

      Bulk.patch(target: "lexeme_senses", columns: {"meanings" => "jsonb"}, rows:)
    end

    def fill_radicals(names)
      written = 0
      Lexeme.where(kind: :radical, text: names.keys).find_each do |radical|
        fresh = names[radical.text].to_s.strip
        next if fresh.empty? || radical.meanings[LOCALE] == fresh

        radical.update!(meanings: radical.meanings.merge(LOCALE => fresh))
        written += 1
      end

      written
    end

    def owned_by_a_page?(lexeme)
      Lexeme::DICTIONARY_KINDS.include?(lexeme.kind.to_sym) && @curated.owns?(lexeme.text, LOCALE)
    end
  end
end
