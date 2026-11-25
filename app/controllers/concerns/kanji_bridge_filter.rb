# frozen_string_literal: true

module KanjiBridgeFilter
  extend ActiveSupport::Concern

  included do
    helper_method :bridge_kind
  end

  private

  def bridge_kind
    return @bridge_kind if defined?(@bridge_kind)

    @bridge_kind = (params[:bridge].presence_in(Huayu::KanjiBridge::WORD_KINDS) if bridge_filterable?)
  end

  def bridge_filterable? = Locales.kanji_bridge? && Huayu::KanjiBridge.words_available?

  def bridge_filtered(scope)
    bridge_kind ? scope.where(text: Huayu::KanjiBridge.word_texts(bridge_kind)) : scope
  end
end
