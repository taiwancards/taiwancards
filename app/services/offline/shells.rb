# frozen_string_literal: true

module Offline
  class Shells
    WIDTHS = ApplicationHelper::PAGE_WIDTHS.keys.freeze

    def call
      I18n.available_locales.to_h { |locale| [locale.to_s, for_locale(locale)] }
    end

    private

    def for_locale(locale)
      I18n.with_locale(locale) do
        WIDTHS.to_h { |width| [width, template(locale, width)] }
      end
    end

    def template(locale, width)
      html = ApplicationController.render(
        template: "offline/shell",
        layout: "layouts/offline_shell",
        assigns: {width: width},
        locale: locale
      )

      shell = Shell.new(html).call
      raise "the offline layout rendered without a main element" if shell.nil?

      shell.fetch("s")
    end
  end
end
