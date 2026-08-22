# frozen_string_literal: true

module PronunciationHelper
  PROMPT_SIZES = {
    4 => "text-4xl sm:text-5xl",
    8 => "text-3xl sm:text-4xl"
  }.freeze

  SMALLEST_PROMPT = "text-2xl sm:text-3xl"

  def prompt_size(text)
    length = text.to_s.length
    PROMPT_SIZES.find { |upto, _| length <= upto }&.last || SMALLEST_PROMPT
  end
end
