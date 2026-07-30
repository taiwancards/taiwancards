# frozen_string_literal: true

module ZhuyinHelper
  TONES = %w[ˊ ˇ ˋ ˪ ˫].freeze
  CHECKED = %w[ㆴ ㆵ ㆶ ㆷ].freeze
  NEUTRAL = "˙"

  def zhuyin_ruby(text, zhuyin, css: nil, context: :entry)
    chars = text.to_s.chars
    syllables = zhuyin.to_s.split(/[[:space:]]+/).reject(&:empty?)

    return tag.span(text, lang: "zh-TW", class: css) unless syllables.size == chars.size

    tag.span(lang: "zh-TW", class: class_names("zy-run", zhuyin_run_class(context), css)) do
      safe_join(chars.zip(syllables).map { |char, syllable| zhuyin_ruby_pair(char, syllable) })
    end
  end

  def zhuyin_position_for(context)
    return "right" if context == :entry || vertical_text?

    current_user&.zhuyin_position || "right"
  end

  def vertical_text?
    current_user&.vertical_text? || false
  end

  def text_flow_class
    vertical_text? ? "zh-vertical" : nil
  end

  CLIP_DIR = Rails.root.join("public/zhuyin")

  def zhuyin_clip(symbol)
    symbol = symbol.to_s.strip
    return if symbol.length != 1

    path = "/zhuyin/#{symbol}.opus"
    CLIP_DIR.join("#{symbol}.opus").exist? ? path : nil
  end

  def zhuyin_clips(text)
    text.to_s.strip.chars.filter_map { |char|
      clip = zhuyin_clip(char)
      [char, clip] if clip
    }
  end

  HANZI_FONTS = %w[kai sans].freeze
  HANZI_FONT_COOKIE = "hanzi_font"
  PINYIN_COOKIE = "show_pinyin"
  MAINLAND_COOKIE = "show_mainland"

  def hanzi_font
    value = cookies[HANZI_FONT_COOKIE].to_s
    HANZI_FONTS.include?(value) ? value : HANZI_FONTS.first
  end

  def kai_font?
    hanzi_font == "kai"
  end

  def html_preference_classes
    class_names("font-kai" => kai_font?, "no-pinyin" => !show_pinyin?, "show-mainland" => show_mainland?)
  end

  def show_pinyin?
    cookies[PINYIN_COOKIE].to_s == "1"
  end

  def show_mainland?
    cookies[MAINLAND_COOKIE].to_s == "1"
  end

  private

  def zhuyin_run_class(context)
    zhuyin_position_for(context) == "over" ? "zy-over" : "zy-right"
  end

  def zhuyin_ruby_pair(char, syllable)
    neutral = syllable.start_with?(NEUTRAL)
    letters = neutral ? syllable.delete_prefix(NEUTRAL) : syllable
    tone = letters[-1] if TONES.include?(letters[-1]) || CHECKED.include?(letters[-1])
    letters = letters[0..-2] if tone

    tag.ruby(class: "zy") do
      safe_join(
        [
          tag.span(char, class: "base"),
          tag.rp("("),
          zhuyin_ruby_text(letters, tone, neutral),
          tag.rp(")")
        ]
      )
    end
  end

  def zhuyin_ruby_text(letters, tone, neutral)
    tag.rt(class: class_names("neutral" => neutral, "checked" => CHECKED.include?(tone))) do
      safe_join(
        [
          (tag.span(NEUTRAL, class: "t0") if neutral),
          letters,
          (tag.span(tone, class: "t") if tone)
        ].compact
      )
    end
  end
end
