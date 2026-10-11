# frozen_string_literal: true

module StarterHelper
  SYMBOL_PINYIN = Huayu::Zhuyin::INITIALS
    .invert
    .merge(Huayu::Zhuyin::FINALS.select { |_, symbol| symbol.length == 1 }.invert)
    .freeze
  TONE_MARKS = {"ˊ" => 2, "ˇ" => 3, "ˋ" => 4}.freeze
  MARK_FOR = {1 => "", 2 => "ˊ", 3 => "ˇ", 4 => "ˋ"}.freeze
  NEUTRAL = "˙"
  HAN = /\p{Han}/
  PINYIN_LESSONS = 6
  TONE_NAMES = %w[first second third fourth neutral].freeze

  def starter_symbol_pinyin(symbol) = SYMBOL_PINYIN[symbol]

  def starter_symbol_clip(symbol) = "/zhuyin/#{symbol}.opus"

  def starter_audio(lexeme)
    moe = audio_for(lexeme)
    return moe.merge(speakable: true) if moe

    starter_sequence(lexeme)
  end

  def starter_tone_note(lexeme)
    syllables = Huayu::PronunciationTarget.new(lexeme).syllables
    return nil if syllables.empty?

    if syllables.one?
      name = TONE_NAMES[syllables.first["tone"].to_i - 1]
      return name && t("starter.tones.#{name}")
    end

    shifted = syllables.select { |part| tone_shifted?(part) }
    return nil if shifted.empty?

    key = shifted.all? { |part| part["base_tone"] == 3 } ? "tone_shift_third" : "tone_shift"
    t("starter.#{key}", word: spoken_word(syllables))
  end

  def starter_phrase(phrase)
    syllables = phrase.zhuyin.split
    runs = phrase.zh.chars.chunk_while { |a, b| a.match?(HAN) == b.match?(HAN) }

    tag.span(lang: "zh-TW") do
      safe_join(
        runs.map do |run|
          next tag.span(run.join) unless run.first.match?(HAN)

          zhuyin_ruby(run.join, syllables.shift(run.size).join(" "))
        end
      )
    end
  end

  private

  def starter_sequence(lexeme)
    syllables = lexeme.headline_zhuyin.to_s.split
    return nil if syllables.empty? || syllables.size != lexeme.text.length

    tones = syllables.map { |syllable| syllable.start_with?(NEUTRAL) ? 5 : TONE_MARKS.fetch(syllable[-1], 1) }
    surface = Huayu::ToneSandhi.surface_tones(chars: lexeme.text.chars, base_tones: tones)
    approximate = false

    urls = syllables.each_with_index.map do |syllable, index|
      base = syllable.delete("ˊˇˋ#{NEUTRAL}")
      tone = surface[index]
      if tone == 5
        next starter_clip_url("#{NEUTRAL}#{base}") if Huayu::CnsVoice.covers?("#{NEUTRAL}#{base}")

        approximate = true
        tone = index.positive? ? surface[index - 1].clamp(1, 4) : 1
      end

      starter_clip_url("#{base}#{MARK_FOR[tone]}")
    end

    return nil if urls.any?(&:nil?)

    {sequence: urls, speakable: !approximate}
  end

  def starter_clip_url(zhuyin)
    clip = Huayu::CnsVoice.for(zhuyin, voice: Huayu::CnsVoice::VOICES.first)
    clip && Huayu::CnsVoice.clip_url(clip.voice, clip.key)
  end
end
