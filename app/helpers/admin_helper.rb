# frozen_string_literal: true

module AdminHelper
  REGIONAL_INDICATOR_OFFSET = 0x1F1A5

  def country_flag(code)
    code.to_s.each_char.map { |char| (char.ord + REGIONAL_INDICATOR_OFFSET).chr(Encoding::UTF_8) }.join
  end

  def whereabouts(user)
    place = user.country.presence && "#{country_flag(user.country)} #{user.country}"
    [place, user.time_zone.presence].compact.join(" · ")
  end

  def visited_pages(addresses) = Admin::VisitedPages.new(addresses)

  def visited_page_link(page, **options)
    content = safe_join(
      [
        (tag.span(page.short_label, class: "text-foreground") if page.label),
        tag.span(page.path, class: "text-muted-foreground")
      ].compact,
      " "
    )
    title = [page.title, (t("admin_pages.hidden_note") if page.hidden)].compact.join(" — ")
    return tag.span(content, title:, **options) unless page.href

    link_to(content, page.href, title:, target: "_blank", rel: "noopener", **options)
  end
end
