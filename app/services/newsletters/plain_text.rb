# frozen_string_literal: true

module Newsletters
  module PlainText
    BLOCKS = %w[div p h1 h2 blockquote pre figure figcaption ul ol].freeze

    module_function

    def call(html)
      require "nokolexbor"

      out = +""
      body = Nokolexbor::HTML(html.to_s).at_css("body")
      walk(body, out) if body
      out.gsub(/[ \t]+\n/, "\n").gsub(/\n[ \t]+/, "\n").gsub(/\n{3,}/, "\n\n").strip
    end

    def walk(node, out)
      node.children.each do |child|
        if child.text?
          out << child.text.gsub(/\s+/, " ")
        else
          element(child, out)
        end
      end
    end

    def element(node, out)
      case node.name
      when "br"
        out << "\n"
      when "img"
        nil
      when "a"
        out << link(node)
      when "li"
        out << "\n• "
        walk(node, out)
      else
        block = BLOCKS.include?(node.name)
        out << "\n" if block
        walk(node, out)
        out << "\n" if block
      end
    end

    def link(node)
      text = node.text.strip
      href = node["href"].to_s
      href.present? && href != text ? "#{text} (#{href})" : text
    end
  end
end
