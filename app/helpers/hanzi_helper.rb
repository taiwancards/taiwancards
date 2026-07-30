# frozen_string_literal: true

module HanziHelper
  HAN = /\p{Han}/

  ERAS = %w[oracle bronze seal clerical].freeze
  SCRIPT_DIR = Rails.root.join("app/assets/images/scripts")

  def evolution_rows
    @evolution_rows ||= SCRIPT_DIR
      .glob("*.svg")
      .group_by { |path| path.basename.to_s.split("-").first }
      .filter_map { |char, paths|
        eras = ERAS.select { |era| paths.any? { |path| path.basename.to_s == "#{char}-#{era}.svg" } }
        [char, eras] if eras.size >= 3
      }
      .sort_by(&:first)
  end

  def evolution_image(char, era)
    "scripts/#{char}-#{era}.svg"
  end

  IDS = {
    "⿰" => "left_right",
    "⿱" => "top_bottom",
    "⿲" => "left_mid_right",
    "⿳" => "top_mid_bottom",
    "⿴" => "surround",
    "⿵" => "surround_top",
    "⿶" => "surround_bottom",
    "⿷" => "surround_left",
    "⿸" => "surround_tl",
    "⿹" => "surround_tr",
    "⿺" => "surround_bl",
    "⿻" => "overlap"
  }.freeze

  SCRIPT = /[\p{Han}\p{Bopomofo}]/
  SCRIPT_RUN = /([\p{Han}\p{Bopomofo}]+)/

  def mark_script(text)
    return "" if text.blank?

    safe_join(
      text.to_s.split(SCRIPT_RUN).map { |part| part.match?(SCRIPT) ? tag.span(part, lang: "zh-TW") : part }
    )
  end

  def hanzi(text, skip: nil, css: "rounded transition-colors hover:bg-primary/15 hover:text-primary")
    return "" if text.blank?

    safe_join(
      text.each_char.map do |char|
        if char == skip || !char.match?(HAN)
          char
        else
          link_to(char, character_path(char), class: css, data: {turbo_frame: "_top"})
        end
      end
    )
  end

  def linked_text(text, words:, skip: nil, max_word: 8)
    return "" if text.blank?

    chars = text.chars
    out = []
    index = 0
    while index < chars.length
      char = chars[index]
      unless char.match?(HAN)
        out << char
        index += 1
        next
      end

      matched = nil
      [max_word, chars.length - index].min.downto(2) do |length|
        candidate = chars[index, length].join
        if words.include?(candidate) && candidate != skip
          matched = candidate
          break
        end
      end

      if matched
        out <<
          link_to(
            matched,
            dict_entry_path(matched),
            class: "rounded transition-colors hover:bg-primary/15 hover:text-primary",
            data: {turbo_frame: "_top"}
          )
        index += matched.length
      elsif char == skip
        out << char
        index += 1
      else
        out <<
          link_to(
            char,
            character_path(char),
            class: "rounded transition-colors hover:bg-primary/15 hover:text-primary",
            data: {turbo_frame: "_top"}
          )
        index += 1
      end
    end

    safe_join(out)
  end

  def decomposition_html(text, skip: nil)
    return "" if text.blank?

    safe_join(
      text.each_char.map do |char|
        if IDS.key?(char)
          label = t("characters.ids.#{IDS[char]}")
          tag.span(
            label,
            class: "mx-1 inline-flex items-center rounded-md bg-muted px-1.5 py-0.5 text-xs font-medium text-muted-foreground align-middle",
            title: label
          )
        elsif char == skip || !char.match?(HAN)
          char == "？" || char == "?" ? "".html_safe : char
        else
          link_to(
            char,
            character_path(char),
            class: "rounded transition-colors hover:bg-primary/15 hover:text-primary",
            data: {turbo_frame: "_top"}
          )
        end
      end
    )
  end
end
