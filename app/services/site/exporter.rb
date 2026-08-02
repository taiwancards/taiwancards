# frozen_string_literal: true

require "action_dispatch/testing/integration"

module Site
  class Exporter
    TRANSLATED = {"/" => "."}.freeze

    ENGLISH_ONLY = {"/licenses" => "licenses", "/privacy" => "privacy", "/terms" => "terms"}.freeze

    PAGES = TRANSLATED.merge(ENGLISH_ONLY).freeze

    STAYS_HERE = PAGES.keys.to_set

    REQUIRED = %w[SITE_URL APP_URL ASSETS_BASE_URL].freeze

    def initialize(root: Rails.root.join("site"), io: $stdout)
      @root = Pathname(root)
      @io = io
      @assets = Set.new
    end

    def call
      missing = REQUIRED.reject { |name| ENV[name].present? }
      raise "site:build needs #{missing.join(", ")} in .env — see .env.dev" if missing.any?

      Site.while_exporting do
        prepare
        I18n.available_locales.each { |locale| TRANSLATED.each_key { |path| write(path, locale) } }
        ENGLISH_ONLY.each_key { |path| write(path, I18n.default_locale) }
        copy_assets
        copy_public
        report
      end
    end

    private

    def prepare
      @root.rmtree if @root.exist?
      @root.mkpath
    end

    def write(path, locale)
      html = rewrite(fetch(path, locale), locale, path)
      target = destination(path, locale)
      target.dirname.mkpath
      target.write(html)
    end

    def destination(path, locale)
      folder = PAGES.fetch(path)
      prefix = locale == I18n.default_locale ? @root : @root.join(locale.to_s)
      folder == "." ? prefix.join("index.html") : prefix.join(folder, "index.html")
    end

    def fetch(path, locale)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host = "localhost"
      session.get(path, headers: {"HTTP_COOKIE" => "locale=#{locale}"})

      unless session.response.successful?
        raise "#{path} for #{locale} answered #{session.response.status}"
      end

      session.response.body
    end

    def rewrite(html, locale, path)
      html = strip_dynamic(html)
      html = collect_and_keep_assets(html)
      html = absolutise_links(html, locale)
      html = unpost_locale_switch(html, path)
      html = canonicalise(html, locale, path)
      html.sub("</head>", "#{behavior}\n</head>")
    end

    def unpost_locale_switch(html, path)
      return html.gsub(%r{<form[^>]*action="/locale/\w+"[^>]*>.*?</form>}m, "") if ENGLISH_ONLY.key?(path)

      html.gsub(%r{<form[^>]*action="/locale/(\w+)"[^>]*>(.*?)</form>}m) do
        target = Regexp.last_match(1).to_sym
        inside = Regexp.last_match(2)
        button = inside[/<button([^>]*)>/, 1].to_s
        label = inside[%r{<button[^>]*>(.*?)</button>}m, 1].to_s

        attributes = %w[class title aria-label].filter_map do |name|
          value = button[/#{name}="([^"]*)"/, 1]
          "#{name}=\"#{value}\"" if value.present?
        end

        "<a href=\"#{local(path, target)}\" #{attributes.join(" ")}>#{label}</a>"
      end
    end

    def canonicalise(html, locale, path)
      here = "#{site_url}#{local(path, locale)}"

      html = html.gsub(%r{https?://localhost(:\d+)?/?}, "#{site_url}/")
      html = html.gsub(%r{<link[^>]*rel="canonical"[^>]*>}) do |tag|
        tag.sub(/href="[^"]*"/, "href=\"#{here}\"")
      end

      html = html.gsub(%r{<meta[^>]*property="og:url"[^>]*>}) do |tag|
        tag.sub(/content="[^"]*"/, "content=\"#{here}\"")
      end

      html.sub("</head>", "#{alternates(path)}\n#{hints}\n</head>")
    end

    def hints
      core = FontAssets.url_for(FontAssets::KAI_CORE)
      lines = ["<link rel=\"preload\" as=\"font\" type=\"font/woff2\" crossorigin href=\"#{core}\">"]

      [FontAssets.base_url, app_url].compact.uniq.each do |origin|
        lines.unshift("<link rel=\"preconnect\" href=\"#{origin}\" crossorigin>")
      end

      lines.join("\n")
    end

    def alternates(path)
      return "" if ENGLISH_ONLY.key?(path)

      I18n
        .available_locales
        .map { |other| "<link rel=\"alternate\" hreflang=\"#{other}\" href=\"#{site_url}#{local(path, other)}\">" }
        .join("\n")
    end

    def app_url = @app_url ||= ENV.fetch("APP_URL").chomp("/")

    def site_url = @site_url ||= ENV.fetch("SITE_URL").chomp("/")

    def strip_dynamic(html)
      html
        .gsub(%r{<meta name="csrf-(param|token)"[^>]*>\n?}, "")
        .gsub(%r{<meta name="csp-nonce"[^>]*>\n?}, "")
        .gsub(%r{<script type="importmap".*?</script>\n?}m, "")
        .gsub(%r{<link rel="modulepreload"[^>]*>\n?}, "")
        .gsub(%r{<script type="module">.*?</script>\n?}m, "")
        .gsub(%r{<link[^>]*rel="manifest"[^>]*>\n?}, "")
        .gsub(/ nonce="[^"]*"/, "")
    end

    def collect_and_keep_assets(html)
      html.gsub(%r{(?:href|src)="(/assets/[^"]+)"}) do |match|
        @assets << Regexp.last_match(1)
        match
      end
    end

    def absolutise_links(html, locale)
      html.gsub(/href="(\/[^"#][^"]*|\/)"/) do
        path = Regexp.last_match(1)
        href = if STAYS_HERE.include?(path)
          local(path, locale)
        elsif path.start_with?("/assets/", "/icon", "/favicon", "/apple-touch-icon", "/manifest")
          path
        else
          "#{app_url}#{path}"
        end

        "href=\"#{href}\""
      end
    end

    def local(path, locale)
      return path if ENGLISH_ONLY.key?(path)

      base = locale == I18n.default_locale ? "" : "/#{locale}"
      path == "/" ? "#{base}/" : "#{base}#{path}"
    end

    def behavior
      <<~HTML
        <script>
        (function () {
          var root = document.documentElement;
          var stored = localStorage.getItem("hanzi_font");
          if (stored !== null) root.classList.toggle("font-kai", stored === "kai");

          var warming = false;
          function warmKai() {
            var url = document.body && document.body.getAttribute("data-kai-font-url-value");
            if (warming || !url || !window.FontFace) return;
            warming = true;
            var load = function () {
              var face = new FontFace("TW Kai", 'url(' + url + ') format("woff2")', {
                style: "normal", weight: "400", display: "swap"
              });
              face.load().then(function (ready) { document.fonts.add(ready); }, function () { warming = false; });
            };
            if (window.requestIdleCallback) requestIdleCallback(load, {timeout: 3000});
            else setTimeout(load, 1200);
          }
          if (root.classList.contains("font-kai")) {
            if (document.readyState === "complete") warmKai();
            else window.addEventListener("load", warmKai, {once: true});
          }

          document.addEventListener("click", function (event) {
            var pref = event.target.closest("[data-controller~='display-pref']");
            if (!pref) return;
            var name = pref.dataset.displayPrefNameValue;
            var css = pref.dataset.displayPrefCssValue;
            var on = pref.dataset.displayPrefOnValue;
            var next = localStorage.getItem(name) === on ? pref.dataset.displayPrefOffValue : on;
            localStorage.setItem(name, next);
            root.classList.toggle(css, next === on);
            if (css === "font-kai" && next === on) warmKai();
          });
        })();
        </script>
      HTML
    end

    def copy_assets
      by_digest = Rails.application.assets.load_path.assets.index_by { |asset| asset.digested_path.to_s }

      @assets.each do |path|
        asset = by_digest[path.delete_prefix("/assets/")]
        raise "#{path} is referenced but Propshaft does not know it" if asset.nil?

        target = @root.join(path.delete_prefix("/"))
        target.dirname.mkpath
        target.binwrite(asset.compiled_content)
      end
    end

    PUBLIC_FILES = %w[favicon.ico icon.svg apple-touch-icon.png og.png robots.txt].freeze

    def copy_public
      PUBLIC_FILES.each do |name|
        source = Rails.public_path.join(name)
        FileUtils.cp(source, @root.join(name)) if source.exist?
      end

      copy_fonts
    end

    def copy_fonts
      from_css = @root.glob("assets/*.css").flat_map { |css| css.read.scan(%r{url\("/fonts/([^"]+)"\)}).flatten }
      from_html = @root.glob("**/*.html").flat_map { |page| page.read.scan(%r{"/fonts/([^"]+)"}).flatten }
      wanted = (from_css + from_html).uniq
      return if wanted.empty?

      target = @root.join("fonts")
      target.mkpath
      wanted.each do |name|
        source = FontAssets.directory.join(name)
        raise "#{name} is referenced by the stylesheets but missing from #{FontAssets.directory}" unless source.exist?

        FileUtils.cp(source, target.join(name))
      end
    end

    def report
      files = @root.glob("**/*").select(&:file?)
      @io.puts(format("site: %d files, %.1f KB in %s", files.length, files.sum(&:size) / 1024.0, @root))
      files.sort.each { |file| @io.puts("  #{file.relative_path_from(@root)}") }
      files
    end
  end
end
