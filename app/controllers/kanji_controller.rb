# frozen_string_literal: true

class KanjiController < ApplicationController
  SECTIONS = %w[shapes readings meanings].freeze

  allow_unauthenticated_access
  publicly_cacheable

  def show
    return redirect_to(hanzi_path) unless Locales.kanji_bridge?

    @section = params[:section].presence_in(SECTIONS) || SECTIONS.first
    @level = params[:level].to_i if Huayu::KanjiBridge::LEVELS.cover?(params[:level].to_i)
    @shifted = shifted_words if @section == "meanings"
  end

  private

  def shifted_words
    words = Huayu::KanjiBridge.words_of("shift")
    levels = Lexeme
      .where(kind: Lexeme::DICTIONARY_KINDS, text: words.map(&:text))
      .pluck(:text, :level_index)
      .each_with_object({}) { |(text, level), memo| memo[text] = [memo[text], level].compact.min }
    grouped = words.group_by { |word| levels[word.text] }
    grouped = grouped.slice(@level) if @level
    grouped.sort_by { |level, _| level || Float::INFINITY }
  end
end
