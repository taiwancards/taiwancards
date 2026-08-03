# frozen_string_literal: true

module StudyHelper
  AUTOPLAY_MS = 500
  SPEECH_GOOD_AT = 72
  SPEECH_HARD_AT = 45

  FACET_ICONS = {
    "recognition" => :characters,
    "production" => :words,
    "reading" => :speaker,
    "listening" => :speaker,
    "tone" => :speaker,
    "writing" => :pencil
  }.freeze

  def facet_icon(facet)
    FACET_ICONS.fetch(facet.to_s, :study)
  end

  def study_card_kind(lexeme:, facet:, memory: nil)
    case facet.to_s
    when "writing"
      Huayu::WritingTarget.new(lexeme).writable? ? :writing : :swipe
    when "tone"
      tone_card_kind(lexeme, memory)
    else
      :swipe
    end
  end

  def tone_card_kind(lexeme, memory)
    speech = voice_calibrated? && Huayu::PronunciationTarget.new(lexeme).syllables.any?
    quiz = Huayu::ToneQuiz.new(lexeme).available?
    return :swipe unless speech || quiz
    return :tone_speech if speech && (!quiz || memory&.reps.to_i.odd?)

    quiz ? :tone_quiz : :tone_speech
  end

  def card_example(lexeme)
    return nil unless lexeme.word?

    @card_examples ||= {}
    return @card_examples[lexeme.id] if @card_examples.key?(lexeme.id)

    @card_examples[lexeme.id] = SentenceWord.for_word(lexeme).includes(:sentence).first&.sentence
  end

  def cloze_text(sentence, word)
    sentence.text.gsub(word, "＿" * word.length)
  end

  def study_next_suggestion
    return nil unless current_user
    case Learn::NextStep.new(current_user).call.kind
    when "zhuyin"
      {label: t("study.up_next.zhuyin"), body: t("study.up_next.zhuyin_body"), path: practice_zhuyin_path}
    when "drill"
      {label: t("study.up_next.drill"), body: t("study.up_next.drill_body"), path: zhuyin_training_path}
    when "typing"
      {label: t("study.up_next.typing"), body: t("study.up_next.typing_body"), path: practice_typing_path}
    else
      {label: t("study.up_next.ahead"), body: t("study.up_next.ahead_body"), path: study_path(mode: "cram")}
    end
  end
end
