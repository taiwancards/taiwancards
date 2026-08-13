# frozen_string_literal: true

module Huayu
  class ChinaMarkerImporter
    TABLES = {hard: "mainland_hard.tsv", soft: "mainland_soft.tsv"}.freeze

    def initialize(io: $stdout)
      @io = io
    end

    def call
      seen = TABLES.flat_map { |band, table| import(band, table) }
      ChinaMarker.where.not(word: seen).update_all(active: false)
      ChinaMarker.reset_cache!
      @io.puts("China markers: #{ChinaMarker.hard.count} hard, #{ChinaMarker.soft.count} soft")
      seen.length
    end

    private

    def import(band, table)
      TWFilter::Tables.columns(table).map do |word, taiwan_form, china_hits, taiwan_hits|
        ChinaMarker
          .find_or_initialize_by(word: word)
          .update!(
            band: band,
            taiwan_form: taiwan_form,
            china_hits: china_hits.to_i,
            taiwan_hits: taiwan_hits.to_i,
            active: true,
            note: "twfilter #{TWFilter::VERSION}: #{china_hits} against #{taiwan_hits} in the reference corpus"
          )
        word
      end
    end
  end
end
