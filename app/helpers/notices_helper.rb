# frozen_string_literal: true

module NoticesHelper
  def notice_lang(source)
    source.present? && source[Locales.key].present? ? I18n.locale.to_s : Locales::DEFAULT
  end

  def notice_text(name, source, **options)
    text = Locales.pick(source)
    return if text.blank?

    content_tag(name, text, lang: notice_lang(source), **options)
  end
end
