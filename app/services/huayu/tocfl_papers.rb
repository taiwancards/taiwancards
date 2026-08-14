# frozen_string_literal: true

module Huayu
  class TocflPapers
    DATA = JsonData.new("huayu/tocfl_papers.json", default: {}, watch: true)

    PAPERS_DIR = "tocfl_official/papers"
    MEDIA_DIR = "tocfl_official"
    BANDS = %w[Novice A B].freeze

    Item = Data.define(:number, :context, :stem, :options) do
      def letters = options.keys.sort

      def option(letter) = options[letter]

      def context? = context.to_s.strip.present?
    end

    Paper = Data.define(
      :slug,
      :band,
      :set,
      :level,
      :skill,
      :paper,
      :transcript,
      :audio,
      :clips,
      :answers,
      :count,
      :items
    ) do
      def to_param = slug

      def listening? = skill == "listening"

      def numbers = (1..count).to_a

      def answer(number) = answers[number.to_s]

      def item(number) = items.find { |row| row.number == number }

      def interactive = items.size

      def label = "#{band} · #{I18n.t("exams.set", number: set)}"
    end

    class << self
      def all = payload

      def available? = payload.any?

      def find(slug) = payload.find { |paper| paper.slug == slug.to_s }

      def by_band = payload.group_by(&:band)

      def paper_file(name)
        contained(AppData.path(PAPERS_DIR), name)
      end

      def clip_file(folder, name)
        return nil if folder.blank?

        contained(AppData.media_path(File.join(MEDIA_DIR, folder)), name)
      end

      def reset!
        DATA.reset!
        remove_instance_variable(:@payload) if defined?(@payload)
        @rows = nil
      end

      private

      def contained(root, name)
        return nil if name.blank?

        base = root.cleanpath
        path = base.join(name.to_s).cleanpath
        return nil unless path.to_s.start_with?("#{base}/") && path.file?

        path
      end

      def payload
        rows = DATA.value
        return @payload if defined?(@payload) && @rows.equal?(rows)

        @rows = rows
        @payload = Array(rows["papers"])
          .map do |row|
            Paper.new(
              slug: row["slug"],
              band: row["band"],
              set: row["set"].to_i,
              level: row["level"],
              skill: row["skill"],
              paper: row["paper"],
              transcript: row["transcript"],
              audio: row["audio"],
              clips: Array(row["clips"]),
              answers: row["answers"] || {},
              count: row["count"].to_i,
              items: build_items(row)
            )
          end
          .freeze
      end

      def build_items(row)
        Array(row["items"]).map do |item|
          Item.new(
            number: item["number"].to_i,
            context: item["context"],
            stem: item["stem"],
            options: item["options"] || {}
          )
        end
      end
    end
  end
end
