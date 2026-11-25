# frozen_string_literal: true

module RegionalNotesHelper
  REGIONAL_NOTE_CLASS = "text-[11px] leading-snug text-muted-foreground"

  def regional_note(section, key, css: "mt-1")
    text = Huayu::RegionalNotes.for(section, key)
    return if text.blank?

    tag.p(phon_markup(text), class: [REGIONAL_NOTE_CLASS, css], data: {regional_note: section})
  end
end
