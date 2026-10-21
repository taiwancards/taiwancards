# frozen_string_literal: true

module DictationHelper
  MARKS = [:exact, :no_tone, :wrong_tone, :sound, nil].freeze

  def dictation_cell(mark)
    case mark
    when :exact
      "bg-emerald-500/10 text-emerald-700 dark:text-emerald-400"
    when nil
      "bg-red-500/10 text-red-700 dark:text-red-400"
    else
      "bg-amber-500/15 text-amber-800 dark:text-amber-300"
    end
  end

  def dictation_dot(mark)
    case mark
    when :exact
      "bg-emerald-500"
    when nil
      "bg-red-500"
    else
      "bg-amber-500"
    end
  end
end
