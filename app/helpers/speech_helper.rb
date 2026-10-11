# frozen_string_literal: true

module SpeechHelper
  def tone_shifted?(part) = part["tone"].present? && part["base_tone"].present? && part["tone"] != part["base_tone"]

  def spoken_zhuyin(part)
    return part["zhuyin"] unless tone_shifted?(part)

    Huayu::Zhuyin.apply_tone(part["zhuyin"].to_s.delete(Huayu::ReadingForms::ZHUYIN_TONES), part["tone"])
  end

  def spoken_pinyin(part)
    tone_shifted?(part) ? Huayu::ReadingForms.marked_pinyin(part["pinyin"], part["tone"]) : part["pinyin"]
  end

  def spoken_word(syllables) = syllables.map { |part| spoken_zhuyin(part) }.join(" ")
end
