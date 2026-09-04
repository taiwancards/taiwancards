# frozen_string_literal: true

module Offline
  class Fragment
    WIDTHS = {"max-w-[88rem]" => "wide", "max-w-5xl" => "medium", "max-w-3xl" => "narrow"}.freeze

    MAIN = %r{<main\b([^>]*)>(.*)</main>}m
    TITLE = %r{<title>(.*?)</title>}m
    NONCE = / nonce="[^"]*"/

    def initialize(html)
      @html = html.to_s
    end

    def call
      body = @html[MAIN, 2]
      return nil if body.nil?

      {"t" => title, "w" => width, "m" => body.strip.gsub(NONCE, "")}
    end

    private

    def title
      raw = @html[TITLE, 1].to_s
      CGI.unescapeHTML(raw).strip
    end

    def width
      attributes = @html[MAIN, 1].to_s
      WIDTHS.find { |token, _| attributes.include?(token) }&.last || "narrow"
    end
  end
end
