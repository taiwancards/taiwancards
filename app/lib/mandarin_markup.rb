# frozen_string_literal: true

class MandarinMarkup
  LANG = "zh-TW"
  DOCUMENT = /\A\s*(?:<!--.*?-->\s*)*(?:<!doctype|<html)/im
  SKIPPED = %w[script style textarea title option noscript svg math].to_set.freeze
  BLOCKS = %w[
    address
    article
    aside
    blockquote
    body
    button
    dd
    details
    dialog
    div
    dl
    dt
    figcaption
    figure
    footer
    form
    h1
    h2
    h3
    h4
    h5
    h6
    header
    label
    legend
    li
    main
    nav
    ol
    p
    section
    summary
    table
    td
    th
    tr
    ul
  ]
    .to_set
    .freeze

  def self.call(html, locale: I18n.locale) = new(locale).call(html)

  def initialize(locale)
    @locale = locale.to_s
    @blocks = {}.compare_by_identity
  end

  def call(html)
    text = html.to_s
    return text unless text.match?(HanScript::SCRIPT) || text.include?(HanScript::CLOSE)

    if text.match?(DOCUMENT)
      document = Nokogiri::HTML5(text)
      mark(document.root)
      document.to_html
    else
      fragment = Nokogiri::HTML5.fragment(text)
      mark(fragment)
      fragment.to_html
    end
  end

  private

  def mark(root)
    return if root.nil?

    unmark_attributes(root)
    root.xpath(".//text()").each do |node|
      content = node.content
      next unless content.match?(HanScript::SCRIPT) || content.include?(HanScript::CLOSE)
      state = openness(node)
      next node.content = HanScript.plain(content) unless state

      context = state == :declared ? "" : own_or_block_text(node, content)
      replace(node, HanScript.parse(content, @locale, context:))
    end
  end

  def unmark_attributes(root)
    root.xpath(".//@*").each do |attribute|
      value = attribute.value
      attribute.value = HanScript.plain(value) if value.match?(HanScript::MARKERS)
    end
  end

  def openness(node)
    node.ancestors.each do |element|
      break unless element.element?
      return false if SKIPPED.include?(element.name)
      next unless element["lang"]
      return false unless element["lang"] == @locale

      return element.name == "html" || :declared
    end

    true
  end

  def own_or_block_text(node, content)
    return content if content.match?(HanScript::KANA) || content.match?(HanScript::FOREIGN)

    block_text(node)
  end

  def block_text(node)
    block = node.ancestors.find { |element| element.element? && BLOCKS.include?(element.name) } || node
    @blocks[block] ||= block.text
  end

  def replace(node, parsed)
    return node.content = parsed.text if parsed.ranges.empty?

    parsed.pieces.each do |piece, mandarin|
      sibling = mandarin ? node.document.create_element("span", piece, lang: LANG) : node
        .document
        .create_text_node(piece)
      node.add_previous_sibling(sibling)
    end

    node.remove
  end
end
