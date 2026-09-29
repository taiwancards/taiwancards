# frozen_string_literal: true

module Newsletters
  class Letter
    attr_reader :locale, :unsubscribe_url, :settings_url

    def initialize(newsletter, locale:, image_src:, link:, unsubscribe_url:, settings_url:)
      @newsletter = newsletter
      @locale = locale.to_s
      @image_src = image_src
      @link = link
      @unsubscribe_url = unsubscribe_url
      @settings_url = settings_url
    end

    def subject = @newsletter.subject(locale)

    def preheader = @newsletter.preheader(locale)

    def html = @html ||= EmailHtml.new(@newsletter.body(locale), image_src: @image_src, link: @link).call

    def buttons
      @buttons ||= @newsletter.buttons_for(locale).map { |button| button.merge(url: @link.call(button[:url])) }
    end

    def text
      [
        PlainText.call(html),
        buttons.map { |button| "#{button[:label]}: #{button[:url]}" }.join("\n").presence,
        "—",
        I18n.t("newsletters.mail.why"),
        I18n.t("newsletters.mail.promise"),
        "#{I18n.t("newsletters.mail.unsubscribe")}: #{unsubscribe_url}"
      ].compact.join("\n\n")
    end
  end
end
