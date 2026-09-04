# frozen_string_literal: true

module Offline
  class Shell
    TITLE_SLOT = "§TITLE§"
    MAIN_SLOT = "§MAIN§"
    CSS_SLOT = "§CSS§"
    JS_SLOT = "§JS§"

    STYLESHEET = %r{<link[^>]*rel="stylesheet"[^>]*>}
    IMPORTMAP = %r{<script type="importmap"[^>]*>.*?</script>}m
    MODULEPRELOAD = %r{<link rel="modulepreload"[^>]*>}
    MODULE_SCRIPT = %r{<script type="module"[^>]*>.*?</script>}m
    DISCARDED = [
      %r{<meta name="csrf-(param|token)"[^>]*>},
      %r{<meta name="csp-nonce"[^>]*>},
      %r{<link[^>]*rel="canonical"[^>]*>},
      %r{<link[^>]*rel="alternate"[^>]*>},
      %r{<meta[^>]*property="og:url"[^>]*>}
    ].freeze

    def initialize(html)
      @html = html.to_s
    end

    def call
      return nil if @html[Fragment::MAIN].nil?

      {"w" => Fragment.new(@html).call.fetch("w"), "s" => template}
    end

    private

    def template
      html = @html.dup
      DISCARDED.each { |pattern| html = html.gsub(pattern, "") }
      html = swap_assets(html)
      html = html.sub(Fragment::TITLE) { "<title>#{TITLE_SLOT}</title>" }
      html.sub(Fragment::MAIN) { "<main#{Regexp.last_match(1)}>#{MAIN_SLOT}</main>" }
    end

    def swap_assets(html)
      html = html.sub(STYLESHEET, CSS_SLOT).gsub(STYLESHEET, "")
      html = html.sub(IMPORTMAP, JS_SLOT).gsub(IMPORTMAP, "")
      html.gsub(MODULEPRELOAD, "").gsub(MODULE_SCRIPT, "").gsub(Fragment::NONCE, "")
    end
  end
end
