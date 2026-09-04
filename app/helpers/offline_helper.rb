# frozen_string_literal: true

module OfflineHelper
  BROWSE_KINDS = %w[
    character
    word
    phrase
    collocation
    sentence
    radical
    measure_word
    particle
    grammar
    text
  ].freeze

  def offline_labels
    {
      groups: Offline::Sections::GROUPS.index_with { |group| t("offline.groups.#{group}") },
      summaries: Offline::Sections::GROUPS.index_with { |group| t("offline.summaries.#{group}") },
      state: %w[missing ready stale].index_with { |state| t("offline.state.#{state}") },
      working: t("offline.state.working", done: "%{done}", total: "%{total}"),
      action: %w[download update].index_with { |name| t("offline.action.#{name}") },
      storage: t("offline.storage", used: "%{used}", quota: "%{quota}"),
      persisted: t("offline.persisted"),
      unavailable: t("offline.unavailable"),
      warn: t("offline.warn_large", size: "%{size}"),
      locale: I18n.locale.to_s,
      unit: t("offline.megabyte")
    }
  end

  def offline_nav
    [
      [:characters, t("nav.tab.dict"), offline_browse_path],
      [:book, t("nav.grammar"), grammar_path],
      [:book, t("nav.graded"), graded_path],
      [:pencil, t("nav.tab.cangjie-lessons"), cangjie_lessons_path],
      [:desk, t("nav.group_taiwan"), everyday_path],
      [:study, t("nav.syllables"), syllables_path]
    ]
  end

  def offline_browse_labels
    {
      all: t("offline.browse.all"),
      kinds: BROWSE_KINDS.index_with { |kind| t("offline.browse.kind.#{kind}") },
      count: t("offline.browse.count", count: "%{count}"),
      empty: t("offline.browse.empty"),
      none: t("offline.browse.none"),
      locale: I18n.locale.to_s
    }
  end
end
