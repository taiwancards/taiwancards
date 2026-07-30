# frozen_string_literal: true

module PhrasesHelper
  CHIP = "rounded-full border px-3 py-1 text-xs font-medium transition-colors"
  CHIP_ON = "border-primary bg-primary text-primary-foreground"
  CHIP_OFF = "border-border hover:bg-muted"

  def phrase_chip_class(active) = "#{CHIP} #{active ? CHIP_ON : CHIP_OFF}"

  def phrase_slot_label(name)
    slot = Huayu::TaiwanPhrases.slot(name)
    slot ? slot.name(I18n.locale) : name
  end
end
