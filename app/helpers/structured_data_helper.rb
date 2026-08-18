# frozen_string_literal: true

module StructuredDataHelper
  def structured_data(payload)
    return if payload.blank?

    tag.script(
      raw(JSON.generate(payload.merge("@context" => "https://schema.org"))),
      type: "application/ld+json"
    )
  end

  def character_structured_data(lexeme, profile)
    {
      "@type" => "DefinedTerm",
      "name" => lexeme.text,
      "inDefinedTermSet" => t("meta.title"),
      "inLanguage" => "zh-Hant-TW",
      "description" => lexeme.meaning.presence,
      "alternateName" => profile.readings.filter_map { |reading| reading["pinyin"].presence }.presence,
      "url" => canonical_url
    }.compact
  end

  def grammar_structured_data(lesson)
    {
      "@type" => "LearningResource",
      "name" => lesson.title(I18n.locale),
      "learningResourceType" => "grammar point",
      "inLanguage" => "zh-Hant-TW",
      "educationalLevel" => lesson.level&.to_s,
      "teaches" => lesson.pattern.presence,
      "url" => canonical_url
    }.compact
  end

  def canonical_url = request.original_url.split("?").first
end
