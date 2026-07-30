# frozen_string_literal: true

module AudioHelper
  def audio_for(lexeme)
    return nil if lexeme.nil?

    clip = Huayu::MoeAudio.for(lexeme.text, zhuyin: primary_zhuyin(lexeme))
    return {url: clip_url(clip), stop_ms: clip.head_ms, source: "moe"} if clip

    parts = Huayu::MoeAudio.per_character(lexeme.text)
    return nil if parts.empty?

    {
      url: clip_url(parts.first),
      stop_ms: parts.first.head_ms,
      source: "moe_per_char",
      parts: parts.map { |part| {url: clip_url(part), stop_ms: part.head_ms} }
    }
  end

  def moe_clip_for(lexeme, zhuyin)
    clip = Huayu::MoeAudio.for(lexeme.text, zhuyin:, strict: true)
    return nil if clip.nil?

    {url: clip_url(clip), stop_ms: clip.head_ms}
  end

  def audio_url_for(lexeme)
    audio_for(lexeme)&.fetch(:url)
  end

  def audio_source_title(audio)
    return nil if audio.nil?

    audio[:source] == "moe_per_char" ? t("audio.source_per_char") : t("audio.source_whole")
  end

  private

  def clip_url(clip)
    Huayu::MoeAudio.clip_url(clip.scope, clip.id)
  end

  def primary_zhuyin(lexeme)
    return nil unless lexeme.respond_to?(:reading_set)

    lexeme.reading_set.filter_map { |reading| reading["zhuyin"].presence }.first
  end
end
