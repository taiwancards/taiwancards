# frozen_string_literal: true

module Deploy
  class Catalog
    Section = Struct.new(:id, :from, :to, :what, :required, :mode, :only, :plain, keyword_init: true) do
      def source = Rails.root.join(from)

      def paths
        return [] unless source.exist?
        return [source] if only.blank?

        only.map { |entry| source.join(entry) }.select(&:exist?)
      end

      def exist? = paths.any?

      def entries = only.presence || ["."]

      def target = to.presence || "."

      def compress? = !plain

      def files
        paths.flat_map { |path| path.file? ? [path] : path.glob("**/*").select(&:file?) }
      end

      def bytes = files.sum(&:size)

      def count = files.length

      def sync_sources
        only.blank? ? ["#{source}/"] : paths.map(&:to_s)
      end
    end

    SECTIONS = [
      Section.new(
        id: "huayu",
        from: "data/huayu",
        to: "huayu",
        what: "dictionaries, glosses and word lists read at runtime",
        required: true,
        mode: :rsync
      ),
      Section.new(
        id: "pronunciation",
        from: "data/pronunciation",
        to: "pronunciation",
        what: "pronunciation templates, thresholds, syllable inventory, drills",
        required: true,
        mode: :atomic,
        only: %w[templates thresholds.json inventory.json drills.json axis_norms.json]
      ),
      Section.new(
        id: "textbook",
        from: "data/textbook",
        to: "textbook",
        what: "Textbook lesson exports that fill the lessons table",
        required: true,
        mode: :rsync
      ),
      Section.new(
        id: "dictionaries",
        from: "dict_and_corpora/dictionaries",
        to: "dictionaries",
        what: "character decomposition, stroke order, simplified to traditional",
        required: true,
        mode: :rsync,
        only: %w[makemeahanzi simp_to_trad.txt]
      ),
      Section.new(
        id: "manifests",
        from: "data",
        to: "",
        what: "content source list and web font manifest, read by deploy:sync",
        required: true,
        mode: :rsync,
        only: %w[content_sources.json fonts.json]
      ),
      Section.new(
        id: "fonts",
        from: "storage/fonts",
        to: "fonts",
        what: "web fonts for FONT_DIR, including the TW-Kai faces that are built, not downloaded",
        required: false,
        mode: :rsync,
        plain: true
      ),
      Section.new(
        id: "json",
        from: "storage/json",
        to: "json",
        what: "browser data files the CDN serves; kept here so their urls can be stamped",
        required: false,
        mode: :rsync
      ),
      Section.new(
        id: "moe_audio",
        from: "media/moe_audio",
        to: "moe_audio",
        what: "MOE character audio manifest, clips are served from the media bucket",
        required: true,
        mode: :rsync,
        only: %w[index.json notice.pdf ATTRIBUTION.txt]
      ),
      Section.new(
        id: "moe_audio_words",
        from: "media/moe_audio_words",
        to: "moe_audio_words",
        what: "MOE word audio manifest, clips are served from the media bucket",
        required: true,
        mode: :rsync,
        only: %w[index.json notice.pdf ATTRIBUTION.txt]
      ),
      Section.new(
        id: "textbook_audio",
        from: "media/audio/textbook",
        to: "audio/textbook",
        what: "Textbook audio",
        required: false,
        mode: :rsync,
        plain: true
      )
    ].freeze

    class << self
      def all = SECTIONS

      def find(id) = SECTIONS.find { |section| section.id == id }

      def select(only: nil, skip: nil)
        ids = SECTIONS.map(&:id)
        wanted = list(only).presence || ids
        excluded = list(skip)
        unknown = (wanted + excluded) - ids
        if unknown.any?
          raise(
            ArgumentError,
            "unknown sections: #{unknown.join(", ")}. Known: #{ids.join(", ")}"
          )
        end

        SECTIONS.select { |section| wanted.include?(section.id) && excluded.exclude?(section.id) }
      end

      def missing = SECTIONS.select { |section| section.required && !section.exist? }

      def plan(sections = SECTIONS)
        sections.map do |section|
          [
            section.id,
            section.from,
            section.target,
            section.compress? ? "gzip" : "plain",
            section.entries.join(" ")
          ].join("\t")
        end
      end

      private

      def list(value) = value.to_s.split(",").map(&:strip).compact_blank
    end
  end
end
