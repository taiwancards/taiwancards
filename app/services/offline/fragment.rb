# frozen_string_literal: true

module Offline
  class Fragment
    MAIN = %r{<main\b([^>]*)>(.*)</main>}m
    TITLE = %r{<title>(.*?)</title>}m
    NONCE = / nonce="[^"]*"/

    def initialize(html)
      @html = html.to_s
    end

    def call
      body = @html[MAIN, 2]
      return nil if body.nil?

      {"t" => title, "m" => body.strip.gsub(NONCE, "")}
    end

    private

    def title
      raw = @html[TITLE, 1].to_s
      CGI.unescapeHTML(raw).strip
    end
  end
end
