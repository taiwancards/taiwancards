# frozen_string_literal: true

module GradedHelper
  FINISH_FORM = "graded-finish"
  BOPOMOFO = /\p{Bopomofo}/
  HAN = /\p{Han}/

  def graded_finish_form = FINISH_FORM

  def aligned_syllables(reading, tokens)
    return nil if reading&.zhuyin.blank? || tokens.blank?

    syllables = reading.zhuyin.split(/[[:space:]]+/).grep(BOPOMOFO)
    words = tokens.reject { |token| token.kind == :literal }.sum { |token| token.text.scan(HAN).size }
    if syllables.size == words &&
        tokens.select { |token| token.kind == :literal }.none? { |token| token.text.match?(HAN) }
      syllables
    end
  end

  def graded_read_label(completion)
    return t("graded.read") unless completion.quizzed?

    t("graded.read_with_score", score: completion.score, total: completion.total)
  end
end
