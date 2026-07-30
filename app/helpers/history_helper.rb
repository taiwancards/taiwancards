# frozen_string_literal: true

module HistoryHelper
  STRENGTH_DOT = {
    strong: "bg-emerald-500",
    familiar: "bg-lime-500",
    learning: "bg-sky-500",
    weak: "bg-red-500",
    new: "bg-zinc-400"
  }.freeze

  RATING_LABEL = {1 => "again", 2 => "hard", 3 => "good", 4 => "easy"}.freeze

  def strength_dot_class(strength)
    STRENGTH_DOT.fetch(strength.to_sym, "bg-zinc-400")
  end

  def facet_dot_title(facet)
    label = t("history.facets.#{facet[:facet]}")
    strength = t("history.strength.#{facet[:strength]}")
    days = facet[:memory]&.stability
    days ? "#{label}: #{strength} · #{days.round}d" : "#{label}: #{strength}"
  end

  def history_last_seen(time)
    return "" if time.nil?

    "#{time_ago_in_words(time)} #{t("history.ago")}"
  end
end
