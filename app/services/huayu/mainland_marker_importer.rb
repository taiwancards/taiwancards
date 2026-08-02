# frozen_string_literal: true

module Huayu
  class MainlandMarkerImporter
    TABLES = {hard: "mainland_hard.tsv", soft: "mainland_soft.tsv"}.freeze

    def initialize(io: $stdout)
      @io = io
    end

    def call
      seen = TABLES.flat_map { |band, table| import(band, table) }
      MainlandMarker.where.not(word: seen).update_all(active: false)
      MainlandMarker.reset_cache!
      @io.puts("mainland markers: #{MainlandMarker.hard.count} hard, #{MainlandMarker.soft.count} soft")
      seen.length
    end

    private

    def import(band, table)
      TWFilter::Tables.columns(table).map do |word, taiwan_form, mainland_hits, taiwan_hits|
        MainlandMarker
          .find_or_initialize_by(word: word)
          .update!(
            band: band,
            taiwan_form: taiwan_form,
            mainland_hits: mainland_hits.to_i,
            taiwan_hits: taiwan_hits.to_i,
            active: true,
            note: "twfilter #{TWFilter::VERSION}: #{mainland_hits} against #{taiwan_hits} in the reference corpus"
          )
        word
      end
    end
  end
end
