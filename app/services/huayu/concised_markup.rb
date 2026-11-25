# frozen_string_literal: true

module Huayu
  module ConcisedMarkup
    NUMBERING = /\A[[:space:]　]*[[:digit:]]+\.[[:space:]　]*/
    SYNONYMS = /[[:space:]　]*△[^\n]*/
    EDGES = /\A[[:space:]　]+|[[:space:]　]+\z/
    LIST = "、"
    CLAUSE = /[。！？，；：]/
    NUMBERING_SQL = "^[[:space:]　]*[0-9]+\\."
    SYNONYMS_SQL = "%△%"

    module_function

    def definition(text)
      return text if text.nil?

      text.sub(NUMBERING, "").gsub(SYNONYMS, "").gsub(EDGES, "").presence
    end

    def chip(text)
      text.to_s.gsub(SYNONYMS, "").gsub(EDGES, "")
    end

    def synonym_list?(text, kind)
      return false unless text.to_s.include?(LIST)

      kind.to_s == "collocation" || !text.match?(CLAUSE)
    end
  end
end
