# frozen_string_literal: true

module LegalHelper
  def legal_section(key)
    tag.section(class: "space-y-2") do
      safe_join([tag.h2(t("#{key}.heading"), class: "text-lg font-semibold"), *legal_body(key)])
    end
  end

  private

  def legal_paragraph(text)
    tag.p(text, class: "text-sm leading-6 text-muted-foreground")
  end

  def legal_body(key)
    items = t("#{key}.items", default: nil)
    body = t("#{key}.body", default: nil)

    [(legal_paragraph(body) if body), (legal_list(items) if items)].compact
  end

  def legal_list(items)
    tag.ul(class: "list-disc space-y-1 pl-5 text-sm leading-6 text-muted-foreground") do
      safe_join(items.map { |item| tag.li(item) })
    end
  end
end
