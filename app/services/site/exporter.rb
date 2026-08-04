# frozen_string_literal: true

require "action_dispatch/testing/integration"

module Site
  class Exporter
    PAGES = {"/" => ".", "/licenses" => "licenses", "/privacy" => "privacy", "/terms" => "terms"}.freeze

    STAYS_HERE = PAGES.keys.to_set

    LEGACY = PAGES.except("/").values.freeze

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
        I18n.available_locales.each { |locale| PAGES.each_key { |path| write(path, locale) } }
        copy_assets
        copy_public
        write_sitemap
        write_root_fallback
        write_legacy_copies
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
      prefix = @root.join(locale.to_s)
      folder == "." ? prefix.join("index.html") : prefix.join(folder, "index.html")
    end

    def fetch(path, locale)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host = "localhost"
      session.get("/#{locale}#{path}".chomp("/"), headers: {"HTTP_COOKIE" => "locale=#{locale}"})

      unless session.response.successful?
        raise "#{path} for #{locale} answered #{session.response.status}"
      end

      session.response.body
    end

    def rewrite(html, locale, path)
      html = strip_dynamic(html)
      html = collect_and_keep_assets(html)
      html = refuse_server_forms(html, path)
      html = absolutise_links(html, locale)
      html = html.gsub(%r{data-search-url-value="(/[^"]*)"}) do
        "data-search-url-value=\"#{app_url}#{Regexp.last_match(1)}\""
      end

      html = canonicalise(html, locale, path)
      html.sub("</head>", "#{behavior}\n</head>")
    end

    def refuse_server_forms(html, path)
      return html unless html.include?("method=\"post\"")

      raise "#{path} still renders a form that only a server can answer"
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
      tags = I18n.available_locales.map do |other|
        "<link rel=\"alternate\" hreflang=\"#{other}\" href=\"#{site_url}#{local(path, other)}\">"
      end

      tags <<
        "<link rel=\"alternate\" hreflang=\"x-default\" " \
          "href=\"#{site_url}#{local(path, I18n.default_locale)}\">"
      tags.join("\n")
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
        .gsub(%r{<link[^>]*rel="alternate"[^>]*>\n?}, "")
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
        bare = Locales.strip(path)
        href = if STAYS_HERE.include?(bare)
          local(bare, Locales.prefix(path) || locale)
        elsif path.start_with?("/assets/", "/icon", "/favicon", "/apple-touch-icon", "/manifest")
          path
        else
          "#{app_url}#{path}"
        end

        "href=\"#{href}\""
      end
    end

    def local(path, locale)
      path == "/" ? "/#{locale}/" : "/#{locale}#{path}"
    end

    def behavior
      <<~HTML
        <script>
        (function () {
          var root = document.documentElement;
          var stored = localStorage.getItem("hanzi_font");
          if (stored !== null) root.classList.toggle("font-kai", stored === "kai");

          document.addEventListener("keydown", function (event) {
            if (event.key !== "Escape") return;
            document.querySelectorAll("[data-menu-target=panel]").forEach(function (panel) {
              panel.classList.add("hidden");
            });
          });

          document.addEventListener("keydown", function (event) {
            if (event.key !== "Enter") return;
            var field = event.target.closest("[data-search-target=input]");
            if (!field || !field.value.trim()) return;
            var box = field.closest("[data-search-url-value]");
            if (!box) return;
            location.href = box.dataset.searchUrlValue + "?q=" + encodeURIComponent(field.value.trim());
          });

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
            var opener = event.target.closest("[data-action~='menu#toggle']");
            var panels = document.querySelectorAll("[data-menu-target=panel]");
            var wanted = opener && opener.parentElement.querySelector("[data-menu-target=panel]");
            var opening = wanted && wanted.classList.contains("hidden");
            panels.forEach(function (panel) { panel.classList.add("hidden"); });
            if (opening) wanted.classList.remove("hidden");

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

    def write_root_fallback
      @root.join("index.html").write(
        <<~HTML
          <!doctype html>
          <html lang="en">
          <head>
          <meta charset="utf-8">
          <title>#{I18n.t("app.name")}</title>
          <link rel="canonical" href="#{site_url}/#{I18n.default_locale}/">
          #{alternates("/")}
          <meta http-equiv="refresh" content="0; url=/#{I18n.default_locale}/">
          <script>
          (function () {
            var wanted = (navigator.language || "en").slice(0, 2);
            var known = #{I18n.available_locales.map(&:to_s).inspect.tr("\"", "'")};
            location.replace("/" + (known.indexOf(wanted) === -1 ? "#{I18n.default_locale}" : wanted) + "/");
          })();
          </script>
          </head>
          <body><a href="/#{I18n.default_locale}/">#{I18n.t("app.name")}</a></body>
          </html>
        HTML
      )
    end

    def write_legacy_copies
      LEGACY.each do |folder|
        target = @root.join(folder, "index.html")
        target.dirname.mkpath
        target.write(@root.join(I18n.default_locale.to_s, folder, "index.html").read)
      end
    end

    def write_sitemap
      entries = PAGES.keys.flat_map { |path| I18n.available_locales.map { |locale| [path, locale] } }

      @root.join("sitemap.xml").write(
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
          #{entries.map { |path, locale| url_entry(path, locale) }.join("\n")}
          </urlset>
        XML
      )

      robots = @root.join("robots.txt")
      robots.write("#{robots.exist? ? robots.read.chomp : ""}\nSitemap: #{site_url}/sitemap.xml\n")
    end

    def url_entry(path, locale)
      links = alternate_links(path).map { |line| "    #{line}" }
      ["  <url>", "    <loc>#{site_url}#{local(path, locale)}</loc>", *links, "  </url>"].join("\n")
    end

    def alternate_links(path)
      I18n.available_locales.map do |other|
        "<xhtml:link rel=\"alternate\" hreflang=\"#{other}\" href=\"#{site_url}#{local(path, other)}\"/>"
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
