# frozen_string_literal: true

module SourceBadgesHelper
  SECTIONS = {
    "Taiwan medicine" => %i[medicine_path medicine.title],
    "Taiwan everyday" => %i[everyday_path everyday.title],
    "Taiwan games" => %i[games_path games.title],
    "moe_idioms" => %i[chengyu_path chengyu.title]
  }.freeze

  def source_badge(source)
    section = SECTIONS[source]
    if section.nil?
      return tag.span(source, class: "rounded-full border border-border px-2.5 py-1 text-muted-foreground")
    end

    path, key = section
    link_to(
      t(key),
      public_send(path),
      class: "rounded-full border border-border px-2.5 py-1 text-muted-foreground hover:bg-muted hover:text-foreground"
    )
  end
end
