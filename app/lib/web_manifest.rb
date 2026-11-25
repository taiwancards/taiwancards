# frozen_string_literal: true

class WebManifest
  ID = "/"
  COLOR = "#ffffff"
  START = "/desk"
  CATEGORIES = %w[education reference].freeze

  ICONS = [
    {src: "/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any"},
    {src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any"},
    {src: "/icon.png", sizes: "512x512", type: "image/png", purpose: "any"},
    {src: "/icon-maskable-192.png", sizes: "192x192", type: "image/png", purpose: "maskable"},
    {src: "/icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable"}
  ].freeze

  SHORTCUTS = [
    {path: "/exams", name: "nav.exams", short: "nav.tab.exams", icon: "/shortcuts/exams.png"},
    {path: "/dict", name: "nav.dict", short: "nav.tab.dict", icon: "/shortcuts/dict.png"},
    {path: "/reader", name: "nav.reader", short: "nav.tab.reader", icon: "/shortcuts/reader.png"},
    {path: "/study", name: "nav.study", short: "nav.study", icon: "/shortcuts/study.png"}
  ].freeze

  SCREENSHOTS = [
    {src: "/screenshots/dict-narrow.png", sizes: "1080x1920", form_factor: "narrow", label: "nav.dict"},
    {src: "/screenshots/characters-narrow.png", sizes: "1080x1920", form_factor: "narrow", label: "nav.characters"},
    {src: "/screenshots/graded-narrow.png", sizes: "1080x1920", form_factor: "narrow", label: "nav.graded"},
    {src: "/screenshots/grammar-narrow.png", sizes: "1080x1920", form_factor: "narrow", label: "nav.grammar"},
    {src: "/screenshots/dict-wide.png", sizes: "1920x1080", form_factor: "wide", label: "nav.dict"},
    {src: "/screenshots/grammar-wide.png", sizes: "1920x1080", form_factor: "wide", label: "nav.grammar"}
  ].freeze

  def self.locale_for(requested) = Locales.known?(requested) ? requested.to_s : Locales::DEFAULT

  def initialize(locale)
    @locale = locale.to_s
  end

  def to_h
    I18n.with_locale(@locale) do
      {
        id: ID,
        name: I18n.t("app.name"),
        short_name: I18n.t("app.name"),
        description: I18n.t("meta.description"),
        lang: @locale,
        dir: "ltr",
        start_url: localized(START),
        scope: "/",
        display: "standalone",
        theme_color: COLOR,
        background_color: COLOR,
        categories: CATEGORIES,
        icons: ICONS,
        screenshots: screenshots,
        shortcuts: shortcuts
      }
    end
  end

  private

  def localized(path) = "/#{@locale}#{path}"

  def shortcuts
    SHORTCUTS.map do |shortcut|
      {
        name: I18n.t(shortcut[:name]),
        short_name: I18n.t(shortcut[:short]),
        url: localized(shortcut[:path]),
        icons: [{src: shortcut[:icon], sizes: "192x192", type: "image/png"}]
      }
    end
  end

  def screenshots
    SCREENSHOTS.map { |shot| shot.merge(type: "image/png", label: I18n.t(shot[:label])) }
  end
end
