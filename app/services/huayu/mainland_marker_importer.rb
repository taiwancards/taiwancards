# frozen_string_literal: true

module Huayu
  class MainlandMarkerImporter
    def initialize(path: nil, io: $stdout)
      @path = Pathname(path || AppData.path("huayu/mainland_markers.json"))
      @io = io
    end

    def call
      unless @path.exist?
        @io.puts("no marker file: #{@path} — run verify_mainland_markers.py first")
        return 0
      end

      entries = JSON.parse(@path.read)
      entries.each do |word, info|
        marker = MainlandMarker.find_or_initialize_by(word: word)
        marker.taiwan_form = info["taiwan"]
        marker.mainland_hits = info["mainland_hits"].to_i
        marker.taiwan_hits = info["taiwan_hits"].to_i
        marker.active = true
        marker.note = "checked against the corpora: #{info["mainland_hits"]} vs #{info["taiwan_hits"]}"
        marker.save!
      end

      MainlandMarker.reset_cache!
      @io.puts("mainland markers: #{MainlandMarker.count}")
      MainlandMarker.count
    end
  end
end
