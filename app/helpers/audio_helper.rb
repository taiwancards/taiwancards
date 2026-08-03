# frozen_string_literal: true

module AudioHelper
  def audio_for(lexeme)
    return nil if lexeme.nil?
    return sentence_audio(lexeme) if lexeme.sentence?

    clip = Huayu::MoeAudio.for(lexeme.text, zhuyin: primary_zhuyin(lexeme))
    return nil if clip.nil?

    {url: clip_url(clip), stop_ms: clip.head_ms, source: "moe"}
  end

  def moe_clip_for(lexeme, zhuyin)
    clip = Huayu::MoeAudio.for(lexeme.text, zhuyin:)
    return nil if clip.nil?

    {url: clip_url(clip), stop_ms: clip.head_ms}
  end

  def audio_url_for(lexeme)
    audio_for(lexeme)&.fetch(:url)
  end

  def audio_source_title(audio)
    audio && t("audio.source_whole")
  end

  private

  def sentence_audio(lexeme)
    clip = Huayu::ListeningClips.for_text(lexeme.text)
    return nil if clip.nil?

    {url: Huayu::ListeningClips.clip_url(clip.clip), stop_ms: 0, source: "common_voice"}
  end

  def clip_url(clip)
    Huayu::MoeAudio.clip_url(clip.scope, clip.id)
  end

  def primary_zhuyin(lexeme)
    return nil unless lexeme.respond_to?(:reading_set)

    lexeme.reading_set.filter_map { |reading| reading["zhuyin"].presence }.first
  end
end
