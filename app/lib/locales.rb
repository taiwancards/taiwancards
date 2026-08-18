# frozen_string_literal: true

module Locales
  ALL = %w[en ru].freeze
  DEFAULT = "en"
  SEGMENT = /\A(#{ALL.join("|")})\z/

  module_function

  def known?(code) = ALL.include?(code.to_s)

  def resolve(url:, stored: nil, header: nil)
    return url.to_s if known?(url)
    return stored.to_s if known?(stored)

    from_header(header) || DEFAULT
  end

  def from_header(header)
    header.to_s.split(",").each do |part|
      tag = part.split(";").first.to_s.strip.downcase
      code = tag.split("-").first
      return code if known?(code)
    end

    nil
  end

  def addressable?(request)
    request.get? && !request.xhr? && html_wanted?(request) && !request.path.start_with?("/rails/")
  end

  def html_wanted?(request)
    request.format.html? || request.formats.any? { |format| format.to_s == "*/*" }
  end

  def alternates(url)
    ALL.to_h { |code| [code, swap(url, code)] }
  end

  BARE = %r{\A/(?:up|auth|audio|manifest|configurations|assets|rails|locale|sitemap|sitemaps|
    textbook/audio|listening/clips|export|progress/data|tones/refill|
    characters/[^/]+/strokes|
    pronunciation/(?:health|grade|thresholds|templates))(?:/|\.|\z|\?)}x

  def prefixable?(path)
    return false unless path.to_s.start_with?("/")

    !path.match?(BARE) && !path.match?(%r{\A/(?:#{ALL.join("|")})(?:/|\z|\?)})
  end

  def prefix(path)
    path.to_s[%r{\A/(#{ALL.join("|")})(?=/|\z|\?)}, 1]
  end

  def strip(path)
    stripped = path.to_s.sub(%r{\A/(?:#{ALL.join("|")})(?=/|\z)}, "")
    stripped.presence || "/"
  end

  def swap(url, code)
    origin, path = split_origin(url.to_s)
    body, query = path.split("?", 2)
    "#{origin}/#{code}#{strip(body).sub(%r{\A/\z}, "")}#{"?#{query}" if query}"
  end

  def split_origin(url)
    match = url.match(%r{\A(\w+://[^/]+)(/.*)?\z})
    return [match[1], match[2].presence || "/"] if match

    ["", url.presence || "/"]
  end
end
