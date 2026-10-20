# frozen_string_literal: true

module DiscoveryHelper
  DISCOVERY_ICONS = {
    "grammar" => :book,
    "graded" => :book,
    "phrases" => :sentences,
    "culture" => :book,
    "pronunciation" => :microphone
  }.freeze

  def discovery_icon(suggestion) = DISCOVERY_ICONS.fetch(suggestion.kind)

  def discovery_path(suggestion)
    case suggestion.kind
    when "grammar"
      grammar_lesson_path(suggestion.subject)
    when "graded"
      graded_text_path(tier: suggestion.subject.tier, id: suggestion.subject.id)
    when "phrases"
      phrases_path(scene: suggestion.subject.id)
    when "culture"
      culture_path(anchor: suggestion.subject.slug)
    else
      pronunciation_path
    end
  end

  def discovery_title(suggestion)
    subject = suggestion.subject
    case suggestion.kind
    when "grammar"
      subject.title(I18n.locale)
    when "graded"
      "#{subject.titles["zh"]} · #{subject.titles[I18n.locale.to_s] || subject.titles["en"]}"
    when "phrases"
      "#{subject.zh} · #{subject.name(I18n.locale)}"
    when "culture"
      subject.culture_for(I18n.locale)["title"]
    else
      t("discovery.pronunciation.title")
    end
  end

  def discovery_body(suggestion)
    case suggestion.kind
    when "grammar"
      t("discovery.grammar.body", level: PlacementHelper::TOCFL_BANDS.fetch(suggestion.level, suggestion.level))
    when "graded"
      t("discovery.graded.body")
    when "phrases"
      t("discovery.phrases.body")
    when "culture"
      t("discovery.culture.body")
    else
      t("discovery.pronunciation.body")
    end
  end
end
