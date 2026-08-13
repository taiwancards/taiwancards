# frozen_string_literal: true

class MedicineController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable
  CATEGORIES = Huayu::MedicineImporter::CATEGORIES

  def show
    @collection = Collection.find_by(kind: :medicine)
    @lexemes = ordered
    @by_text = @lexemes.index_by(&:text)
    @sections = sectioned
    @cards = @by_text.transform_values { |lexeme| card_for(lexeme) }
  end

  private

  def ordered
    return [] if @collection.nil?

    @collection
      .lexemes
      .visible_to(current_user)
      .order(Arel.sql("collection_items.position"))
      .to_a
  end

  def sectioned
    groups = @lexemes.group_by { |lexeme| lexeme.data.dig("med", "category") }
    CATEGORIES.filter_map { |category| [category, groups[category]] if groups[category].present? }
  end

  def card_for(lexeme)
    med = lexeme.data["med"] || {}
    pair_text = med["folk"] || med["formal"]
    pair = @by_text[pair_text]
    {
      text: lexeme.text,
      zhuyin: lexeme.readings["zhuyin"],
      pinyin: lexeme.readings["pinyin"],
      meaning: lexeme.meaning(I18n.locale),
      note: lexeme.data.dig("note", I18n.locale.to_s),
      pairLabel: (t("medicine.#{med["folk"] ? "folk_label" : "formal_label"}") if pair_text),
      pairText: pair_text,
      pairReading: pair && (pair.readings["zhuyin"] || pair.readings["pinyin"]),
      href: dict_entry_path(lexeme.text)
    }.compact
  end
end
