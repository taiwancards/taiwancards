# frozen_string_literal: true

module WordsHelper
  STATE_DOTS = {
    known: "bg-emerald-500",
    learning: "bg-amber-500",
    new: "bg-muted-foreground/30"
  }.freeze

  TONE_DOTS = {
    "positive" => "bg-emerald-500",
    "neutral" => "bg-sky-500",
    "negative" => "bg-rose-500"
  }.freeze

  def word_state_dot(state)
    STATE_DOTS.fetch(state, STATE_DOTS[:new])
  end

  def chengyu_tone_dot(tone)
    TONE_DOTS.fetch(tone.to_s, "bg-muted-foreground/30")
  end

  def word_exists?(text)
    return false if text.blank?

    @word_exists ||= {}
    @word_exists.fetch(text) do
      @word_exists[text] = Lexeme.exists?(kind: :word, text:)
    end
  end
end
