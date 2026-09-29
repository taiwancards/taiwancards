# frozen_string_literal: true

module Offline
  class Shells
    KEY = "page"

    def call
      I18n.available_locales.to_h { |locale| [locale.to_s, for_locale(locale)] }
    end

    private

    def for_locale(locale)
      I18n.with_locale(locale) { {KEY => template(locale)} }
    end

    def template(locale)
      html = ApplicationController.render(
        template: "offline/shell",
        layout: "layouts/offline_shell",
        locale: locale
      )

      shell = Shell.new(html).call
      raise "the offline layout rendered without a main element" if shell.nil?

      shell.fetch("s")
    end
  end
end
