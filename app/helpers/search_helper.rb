# frozen_string_literal: true

module SearchHelper
  NATIVE_TAIGI = "native"

  def lexeme_search_path(lexeme)
    case lexeme.kind.to_sym
    when :character
      character_path(lexeme.text)
    when :word, :collocation
      dict_entry_path(lexeme.text)
    when :radical
      radical_path(lexeme.text)
    when :measure_word
      liangci_entry_path(lexeme.text)
    end
  end

  def lexeme_kind_label(lexeme)
    if lexeme.phrase?
      lexeme.data["sentence"] ? t("search.kind.sentence") : t("search.kind.collocation")
    else
      t("search.kind.#{lexeme.kind}")
    end
  end

  def search_reading(lexeme, query = nil)
    reading = lexeme.reading_set.first || {}
    return reading["pinyin"].presence || reading["zhuyin"] if search_source(query) == :pinyin

    reading["zhuyin"].presence || reading["pinyin"]
  end

  def search_taigi_reading(lexeme, query = nil)
    hokkien = lexeme.data["hokkien"]
    return nil unless hokkien.is_a?(Hash) && hokkien["reading"] == NATIVE_TAIGI

    say = hokkien["say"]
    return nil unless say.is_a?(Hash)
    return say["pinyin"].presence || say["zhuyin"] if search_source(query) == :pinyin

    say["zhuyin"].presence || say["pinyin"]
  end

  def search_query_param(query)
    case search_source(query)
    when :pinyin
      :pinyin
    when :zhuyin
      :zhuyin
    else
      :q
    end
  end

  def search_source(query)
    return nil if query.blank?

    @search_source ||= {}
    @search_source.fetch(query) do
      parsed = Huayu::ReadingQuery.call(query)
      @search_source[query] = parsed.reading? ? parsed.source : nil
    end
  end
end
