# frozen_string_literal: true

module Huayu
  class MedicineImporter < CuratedPageImporter
    PATH = AppData.path("huayu/medicine.json")
    SOURCE = "Taiwan medicine"
    COLLECTION = "Taiwan medicine"
    COLLECTION_KIND = :medicine
    COLLECTION_POSITION = 910
    CATEGORIES = %w[body organs symptoms diseases vaccines hospital departments treatment people nhi].freeze

    private

    def accepted?(entry) = super && CATEGORIES.include?(entry["category"].to_s)

    def payload(entry)
      {
        "med" => {
          "category" => entry["category"],
          "tier" => tier(entry),
          "folk" => entry["folk"].presence,
          "formal" => entry["formal"].presence
        }.compact
      }
    end

    def refresh_examples(data, entry, guarded)
      fresh = examples(entry)
      data["examples"] = guarded ? examples_union(data["examples"], fresh) : fresh
    end

    def shared_metadata(entry) = super.merge("hokkien" => hokkien(entry))
  end
end
