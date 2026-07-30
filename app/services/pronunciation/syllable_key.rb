# frozen_string_literal: true

module Pronunciation
  module SyllableKey
    module_function

    def for(target, store: TemplateStore.instance)
      explicit = target["key"].presence
      return explicit if explicit && store.template(explicit)

      options = candidates(target)
      options.find { |key| store.template(key) } || explicit || options.first
    end

    def candidates(target)
      tone = target["tone"].presence || Huayu::Zhuyin.tone(target["pinyin"])
      base = Huayu::ReadingForms.plain_pinyin(target["pinyin"])
      return [] if base.blank?

      [base, base.tr("v", "u")].uniq.map { |form| "#{form}#{tone}" }
    end
  end
end
