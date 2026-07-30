# frozen_string_literal: true

module PartsOfSpeechHelper
  def parts_of_speech(lexeme)
    tocfl = lexeme.data["pos"].to_s.split(%r{[/／]}).filter_map { |code| tocfl_pos_label(code.strip) }
    return tocfl if tocfl.any?

    Array(lexeme.data["pos_moe"]).filter_map { |tag| moe_pos_label(tag) }
  end

  def tocfl_pos_label(code)
    return nil if code.blank?

    key = code.tr("-", "_").downcase
    I18n.t("pos.tocfl.#{key}", default: nil)
  end

  def moe_pos_label(tag)
    I18n.t("pos.moe.#{tag}", default: nil)
  end
end
