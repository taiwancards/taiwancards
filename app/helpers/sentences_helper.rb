# frozen_string_literal: true

module SentencesHelper
  def scheme_level_label(scheme, level)
    return level unless scheme.to_s == "freq"
    return level if level.start_with?("+")

    t("sentences.top_n", n: level)
  end
end
