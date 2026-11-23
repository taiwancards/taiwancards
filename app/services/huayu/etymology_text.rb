# frozen_string_literal: true

module Huayu
  module EtymologyText
    PLACEHOLDER = /^\(please add [^)]*\)$\n?/

    WORDING = [
      [/\bthe Mainland Mandarin\b/, "China's Mandarin"],
      [/\bMainland Mandarin\b/, "Mandarin in China"],
      [/\bMainland slang senses\b/, "slang senses in China"],
      [/\bMainland Chinese\b/, "Chinese"],
      [/\b[Mm]ainland China\b/, "China"],
      [/\bthe [Mm]ainland\b/, "China"]
    ].freeze

    REDIRECT = [
      /\AFor pronunciation and definitions of .+ – see .+\z/,
      /\A\(This character is .+\)\.?\z/,
      /\ANotes:\z/,
      /\A(?:Simplified|Traditional) Chinese is mainly used in .+\z/
    ].freeze
    GAP = /\s*\[(?:script needed|Term\?)\]/
    LINK = %r{\s*https?://\S+?(?=[.,;)]*(?:\s|\z))}
    HEADING = /\A;+\s*/
    INDENT = /\A:+\s*/
    LONG_HEADING = 90
    BARE_LABEL = /\A(?:["“„][^"“”„\n]*["”“]|\([^()\n]*\))\z/

    module_function

    def normalize(text)
      body = TraditionalOnly.normalize(text)
      return body if body.empty?

      body = WORDING.reduce(body) { |carry, (pattern, wording)| carry.gsub(pattern, wording) }
      cleaned = unlist(body.gsub(PLACEHOLDER, "").gsub(GAP, "").gsub(LINK, ""))
      bare_label?(cleaned) ? "" : cleaned
    end

    def bare_label?(text)
      text.to_s.strip.match?(BARE_LABEL)
    end

    def unlist(body)
      lines = body.lines.map(&:strip).reject { |line| filler?(line) }

      lines.each_with_index.filter_map { |line, index| plain(line, lines[index + 1]) }.join("\n").rstrip
    end

    def filler?(line)
      line.empty? || line.match?(/\A[:;]+\z/) || REDIRECT.any? { |pattern| line.match?(pattern) }
    end

    def plain(line, following)
      return heading(line.sub(HEADING, ""), following) if line.start_with?(";")
      return line unless line.start_with?(":")

      item = line.sub(INDENT, "")
      item.start_with?("*") ? "* #{item.delete_prefix("*").lstrip}" : item
    end

    def heading(title, following)
      return title if title.length > LONG_HEADING
      return nil if following.nil? || following.start_with?(";")

      title.end_with?(":", ".") ? title : "#{title}:"
    end
  end
end
