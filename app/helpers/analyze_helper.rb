# frozen_string_literal: true

module AnalyzeHelper
  POS_COLORS = {
    "n" => "text-sky-600",
    "v" => "text-rose-600",
    "vs" => "text-amber-600",
    "a" => "text-amber-600",
    "adv" => "text-violet-600",
    "m" => "text-teal-600",
    "prep" => "text-cyan-600",
    "conj" => "text-indigo-600",
    "ph" => "text-emerald-600"
  }.freeze

  def pos_color(pos)
    return "text-foreground" if pos.blank?

    key = pos.to_s.downcase
    POS_COLORS[key] || POS_COLORS[key[0]] || "text-foreground"
  end

  def analyze_token_payload(token)
    lexeme = token.lexeme
    {
      text: token.text,
      pos: lexeme&.data&.dig("pos"),
      zhuyin: lexeme&.reading_set&.first&.dig("zhuyin"),
      pinyin: lexeme&.reading_set&.first&.dig("pinyin"),
      meaning: lexeme&.meaning(I18n.locale),
      audio: audio_url_for(lexeme),
      href: character_or_word_path(token),
      lexemeId: lexeme&.id,
      chars: token.chars.map do |char|
        {
          text: char.text,
          zhuyin: char.reading_set.first&.dig("zhuyin"),
          meaning: char.meaning(I18n.locale)
        }
      end
    }.compact
  end

  def character_or_word_path(token)
    first_han = token.text.each_char.find { |char| char.match?(/\p{Han}/) }
    character_path(first_han) if first_han
  end
end
