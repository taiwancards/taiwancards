# frozen_string_literal: true

module GlossaryHelper
  def glossary_terms
    @glossary_terms ||= I18n.t("glossary", default: {}).transform_keys(&:to_s)
  end

  def with_glossary(text)
    seen = (@glossary_seen ||= Set.new)
    pattern = glossary_pattern
    return text if pattern.nil?

    marked = text.to_s.gsub(pattern) do |match|
      key = glossary_key_for(match)
      next match if key.nil? || seen.include?(key)

      seen << key
      tag.abbr(match, title: glossary_terms[key], class: "glossary")
    end

    sanitize(marked, tags: %w[abbr span], attributes: %w[title class lang])
  end

  private

  def glossary_pattern
    return nil if glossary_terms.empty?

    @glossary_pattern ||= Regexp.union(
      glossary_labels.sort_by { |label| -label.length }.map { |label| /#{Regexp.escape(label)}/ }
    )
  end

  def glossary_labels
    @glossary_labels ||= glossary_terms.keys.map { |key| glossary_label(key) }
  end

  def glossary_label(key)
    I18n.t("glossary_labels.#{key}", default: key.tr("_", "-").upcase)
  end

  def glossary_key_for(match)
    glossary_terms.keys.find { |key| glossary_label(key) == match }
  end
end
