# frozen_string_literal: true

module Newsletters
  class EmailHtml
    TEXT = "#262626"
    MUTED = "#737373"
    ACCENT = "#0f766e"
    IMAGE_WIDTH = 544

    STYLES = {
      "div" => "margin:0 0 16px;",
      "p" => "margin:0 0 16px;",
      "h1" => "margin:28px 0 12px;font-size:21px;line-height:1.3;font-weight:700;color:#111111;",
      "h2" => "margin:24px 0 10px;font-size:18px;line-height:1.3;font-weight:700;color:#111111;",
      "blockquote" => "margin:0 0 16px;padding:2px 0 2px 14px;border-left:3px solid #d4d4d4;color:#525252;",
      "ul" => "margin:0 0 16px;padding-left:22px;",
      "ol" => "margin:0 0 16px;padding-left:22px;",
      "li" => "margin:0 0 6px;",
      "pre" => "margin:0 0 16px;padding:12px;background:#f5f5f5;border-radius:8px;font-size:13px;white-space:pre-wrap;",
      "figure" => "margin:0 0 20px;",
      "figcaption" => "margin:8px 0 0;font-size:13px;line-height:1.4;color:#{MUTED};",
      "img" => "display:block;width:100%;max-width:#{IMAGE_WIDTH}px;height:auto;border:1px solid #e5e5e5;border-radius:8px;",
      "a" => "color:#{ACCENT};text-decoration:underline;"
    }.freeze
    BUTTON = "display:inline-block;padding:12px 20px;background:#111111;color:#ffffff;font-size:15px;" \
      "font-weight:600;text-decoration:none;border-radius:10px;"

    def initialize(html, image_src:, link:)
      @html = html.to_s
      @image_src = image_src
      @link = link
    end

    def call
      require "nokolexbor"

      body = Nokolexbor::HTML(@html).at_css("body")
      return "" if body.nil?

      body.css("*").each { |node| dress(node) }
      body.inner_html
    end

    private

    def dress(node)
      style = STYLES[node.name]
      node["style"] = style if style
      case node.name
      when "a"
        node["href"] = @link.call(node["href"].to_s)
        node["style"] = BUTTON if button?(node.parent)
      when "img"
        place_image(node)
      when "div", "p"
        node["style"] = "margin:0;" if nested_block?(node)
      end
    end

    def place_image(node)
      id = node["src"].to_s[Body::IMAGE, 1]
      source = id && @image_src.call(id.to_i)
      return node.remove if source.nil?

      node["src"] = source
      node["width"] = [node["width"].to_i, IMAGE_WIDTH].reject(&:zero?).min.to_s
      node.remove_attribute("height")
      node["alt"] = node["alt"].to_s
    end

    def nested_block?(node) = node.css("div, p, ul, ol, figure, blockquote, h1, h2").any?

    def button?(block)
      return false unless block && %w[div p].include?(block.name)

      parts = block.children.reject { |child| child.name == "br" || (child.text? && child.text.blank?) }
      parts.one? && parts.first.name == "a" && parts.first.text.present?
    end
  end
end
