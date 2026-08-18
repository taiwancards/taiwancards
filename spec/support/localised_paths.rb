# frozen_string_literal: true

module LocalisedPaths
  MACHINE = %r{\A/(?:up|auth|audio|manifest|configurations|assets|rails|s/|locale|zhuyin|
    sitemap|sitemaps|
    textbook/audio|listening/clips|export|progress/data|tones/refill|
    pronunciation/(?:health|grade|thresholds|templates))(?:/|\.|\z|\?)}x

  STROKES = %r{\A/characters/[^/]+/strokes}

  %i[get post patch put delete head].each do |verb|
    define_method(verb) do |path, **options|
      super(localise(path), **options)
    end
  end

  def default_url_options = {locale: I18n.locale}

  def raw_get(path, **)
    method(:get).super_method.call(path, **)
  end

  def in_locale(code)
    previous = I18n.locale
    I18n.locale = code
    integration_session.default_url_options = {locale: code}
    yield
  ensure
    I18n.locale = previous
    integration_session.default_url_options = {locale: previous}
  end

  private

  def localise(path)
    return path unless path.is_a?(String) && path.start_with?("/")
    return path if path.match?(MACHINE) || path.match?(STROKES)
    return path if path.match?(%r{\A/(?:#{Locales::ALL.join("|")})(?:/|\z|\?)})

    "/#{I18n.locale}#{path}".chomp("/")
  end
end
