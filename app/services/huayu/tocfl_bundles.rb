# frozen_string_literal: true

module Huayu
  class TocflBundles
    MANIFEST_PATH = "huayu/tocfl_bundles.json"
    MANIFEST = JsonData.new(MANIFEST_PATH, default: {}, watch: true)
    LEVELS = JsonData.new("huayu/tocfl_levels.json", default: {}, watch: true)
    SOURCE_DIR = "tocfl_official/bundles"
    PAPERS_DIR = "tocfl_official/papers"
    PAPER_MOUNT = "tocfl_pdf"
    BUNDLE_FILE = "bundle.json"
    ASSET_MOUNT = "tocfl_papers"
    MEDIA_MOUNT = "tocfl_official"
    DIGEST_LENGTH = 12

    Part = Data.define(:id, :title, :count, :plays)

    Bundle = Data.define(:slug, :digest, :minutes, :count, :levels, :parts, :scale, :papers) do
      def paper_for(locale) = papers[locale.to_s] || papers["base"]

      def thresholds = Array(scale&.dig("thresholds"))

      def scaled? = scale.is_a?(Hash) && scale["table"].present?

      def scale_max = scale&.dig("max")

      def scaled(raw)
        return nil unless scaled?

        row = scale["table"].select { |entry| entry[0] <= raw }.max_by(&:first)
        row && row[1]
      end

      def level_for(score)
        return nil if score.nil?

        Array(scale&.dig("thresholds"))
          .select { |entry| score >= entry["min"] }
          .max_by { |entry| entry["min"] }
          &.dig("level")
      end
    end

    class << self
      def find(slug) = payload[slug.to_s]

      def available?(slug) = payload.key?(slug.to_s)

      def bundle_url(bundle) = "#{assets_base}/#{ASSET_MOUNT}/#{bundle.slug}/#{BUNDLE_FILE}?v=#{bundle.digest}"

      def media_base = "#{media_root_url}/#{MEDIA_MOUNT}/"

      def paper_url(file) = file.present? ? "#{assets_base}/#{PAPER_MOUNT}/#{ERB::Util.url_encode(file)}" : nil

      def papers_root = AppData.path(PAPERS_DIR)

      def source_root = AppData.path(SOURCE_DIR)

      def audio_root = AppData.media_path(MEDIA_MOUNT)

      def build(source: source_root)
        source.glob("*/#{BUNDLE_FILE}").sort.to_h do |file|
          bundle = JSON.parse(file.read)
          [bundle.fetch("slug"), summarize(bundle, tree_digest(file.dirname))]
        end
      end

      def write!(source: source_root, target: AppData.target_path(MANIFEST_PATH))
        bundles = build(source:)
        target.dirname.mkpath
        target.write("#{JSON.pretty_generate({"bundles" => bundles})}\n")
        reset!
        bundles
      end

      def key_conflicts(source: source_root)
        source.glob("*/#{BUNDLE_FILE}").sort.flat_map do |file|
          bundle = JSON.parse(file.read)
          paper = TocflPapers.find(bundle["slug"])
          next ["#{bundle["slug"]}: no paper of that slug in #{TocflPapers::DATA.path}"] if paper.nil?

          (bundle["key"] || {}).filter_map do |number, letter|
            expected = paper.answer(number.to_i)
            "#{bundle["slug"]} ##{number}: bundle #{letter}, paper key #{expected}" unless expected == letter
          end
        end
      end

      def missing_audio(source: source_root, root: audio_root)
        source.glob("*/#{BUNDLE_FILE}").sort.flat_map do |file|
          bundle = JSON.parse(file.read)
          clip_paths(bundle).reject { |path| root.join(path).file? }.map { |path| "#{bundle["slug"]}: #{path}" }
        end
      end

      def missing_papers(source: source_root, root: papers_root)
        source.glob("*/#{BUNDLE_FILE}").sort.flat_map do |file|
          bundle = JSON.parse(file.read)
          papers_of(bundle).values.uniq.reject { |name| root.join(name).file? }.map { |name|
            "#{bundle["slug"]}: #{name}"
          }
        end
      end

      def reset!
        MANIFEST.reset!
        LEVELS.reset!
        remove_instance_variable(:@payload) if defined?(@payload)
        @rows = nil
      end

      private

      def assets_base = SharedAssets.base_url.to_s

      def media_root_url = ENV["MEDIA_BASE_URL"].presence&.chomp("/").to_s

      def summarize(bundle, digest)
        {
          "digest" => digest,
          "minutes" => bundle["minutes"],
          "count" => bundle["count"],
          "levels" => Array(bundle["levels"]),
          "clips" => clip_paths(bundle),
          "parts" => Array(bundle["parts"]).map do |part|
            {
              "id" => part["id"],
              "title" => part["title"],
              "count" => Array(part["groups"]).sum { |group| Array(group["items"]).size },
              "plays" => part["plays"]
            }
          end,
          "scale" => scale_with_levels(bundle),
          "papers" => papers_of(bundle)
        }
      end

      def scale_with_levels(bundle)
        scale = bundle["scale"]
        return scale if scale.blank? || Array(scale["thresholds"]).any?

        published = LEVELS.value.dig("thresholds", bundle["skill"].to_s, bundle["band"].to_s)
        return scale if published.blank?

        scale.merge("thresholds" => published, "thresholds_source" => LEVELS.value.dig("source", "title"))
      end

      def papers_of(bundle)
        editions = (bundle["editions"] || {}).to_h { |code, edition| [code, edition["paper"]] }.compact
        {"base" => bundle["paper"]}.compact.merge(editions)
      end

      def tree_digest(directory)
        digest = Digest::SHA256.new
        directory.glob("**/*").select(&:file?).sort.each do |file|
          digest << file.relative_path_from(directory).to_s << "\0" << Digest::SHA256.file(file).digest
        end

        digest.hexdigest[0, DIGEST_LENGTH]
      end

      def clip_paths(bundle)
        parts = Array(bundle["parts"])
        base = Array(bundle["opening_clips"]) +
          parts.flat_map { |part| Array(part.dig("intro", "clips")) } +
          parts.flat_map { |part| Array(part["groups"]).flat_map { |group| Array(group["clips"]) } } +
          Array(bundle["closing_clips"])
        within(bundle["audio"], base) + edition_paths(bundle)
      end

      def edition_paths(bundle)
        (bundle["editions"] || {})
          .values
          .reject { |edition| edition["base"] || edition["audio"].blank? }
          .flat_map do |edition|
            names = Array(edition["opening_clips"]) +
              Array(edition["closing_clips"]) +
              (edition["intros"] || {}).values.flat_map { |intro| Array(intro["clips"]) } +
              (edition["clips"] || {}).values
            within(edition["audio"], names)
          end
      end

      def within(folder, names) = names.uniq.map { |name| folder.present? ? File.join(folder, name) : name }

      def payload
        rows = MANIFEST.value
        return @payload if defined?(@payload) && @rows.equal?(rows)

        @rows = rows
        @payload = (rows["bundles"] || {}).to_h { |slug, row| [slug, bundle_from(slug, row)] }.freeze
      end

      def bundle_from(slug, row)
        Bundle.new(
          slug:,
          digest: row["digest"].to_s,
          minutes: row["minutes"].to_i,
          count: row["count"].to_i,
          levels: Array(row["levels"]),
          parts: Array(row["parts"]).map do |part|
            Part.new(id: part["id"], title: part["title"].to_s, count: part["count"].to_i, plays: part["plays"].to_i)
          end,
          scale: row["scale"],
          papers: row["papers"] || {}
        )
      end
    end
  end
end
