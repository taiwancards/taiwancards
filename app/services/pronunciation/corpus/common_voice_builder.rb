# frozen_string_literal: true

require "csv"
require "json"
require "fileutils"
require "open3"
require "open-uri"
require "rubygems/package"

module Pronunciation
  module Corpus
    class CommonVoiceBuilder
      DIR = "corpus_cv"
      LOCALE = "zh-TW"
      RATE = 22_050
      REPO = "fsicoli/common_voice_22_0"
      RELEASE = "Common Voice 22.0 zh-TW"
      BUCKETS = %w[train dev test].freeze
      BIRTHPLACE = "出生地"
      HAN = /\p{Han}/
      LENGTHS = (VariabilityBuilder::MIN_CHARS..VariabilityBuilder::MAX_CHARS)
      LICENSE = "CC0-1.0"
      FILTER = "дикторы с указанным местом рождения на Тайване (поле accents), " \
        "фразы в #{LENGTHS.min}–#{LENGTHS.max} иероглифа — длиннее не режется на слоги надёжно"
      ROLE = "допуск и нормализация по диктору; в центр эталона НЕ идёт (предложения, не цитатные формы)"

      def initialize(repo: REPO, release: RELEASE, archive: nil, io: nil, base: nil)
        @repo = repo
        @release = release
        @archive = archive
        @io = io
        @root = (base && File.join(base, DIR)) || AppData.media_path("pronunciation/#{DIR}").to_s
        @link = File.join(TemplateStore.instance.root, DIR)
        @work = File.join(@root, ".work")
      end

      def build!
        FileUtils.mkdir_p(File.join(@root, "audio"))
        FileUtils.mkdir_p(@work)
        link!

        wanted = rows
        @io&.puts("  #{@release}: #{wanted.length} clips from #{speakers(wanted)} speakers with a birthplace")
        converted = harvest(wanted)
        clips = wanted.select { |row| File.exist?(wav_path(row["path"])) }
        write(clips)

        FileUtils.rm_rf(@work)
        report(clips, converted)
      end

      private

      def speakers(rows) = rows.map { |row| row["client_id"] }.uniq.length

      def link!
        return if File.exist?(@link) || File.symlink?(@link)

        FileUtils.ln_s(Pathname(@root).relative_path_from(Pathname(File.dirname(@link))).to_s, @link)
      end

      def rows
        tables = @archive ? [archive_table] : BUCKETS.map { |bucket| remote_table(bucket) }
        seen = {}
        tables.flatten(1).each do |row|
          next unless row["accents"].to_s.include?(BIRTHPLACE)
          next unless LENGTHS.cover?(row["sentence"].to_s.scan(HAN).length)

          seen[row["path"]] ||= row
        end

        seen.values
      end

      def remote_table(bucket)
        parse(download("#{base_url}/transcript/#{LOCALE}/#{bucket}.tsv", "#{bucket}.tsv"))
          .each { |row| row["_bucket"] = bucket }
      end

      def archive_tsv
        @archive_tsv ||= Dir.glob(File.join(@archive, "**", LOCALE, "validated.tsv")).first ||
          raise("no #{LOCALE}/validated.tsv under #{@archive}")
      end

      def archive_table = parse(archive_tsv)

      def parse(path)
        CSV.read(path, col_sep: "\t", headers: true, quote_char: nil, encoding: "utf-8").map(&:to_h)
      end

      def base_url = "https://huggingface.co/datasets/#{@repo}/resolve/main"

      def download(url, name)
        target = File.join(@work, name)
        return target if File.size?(target)

        @io&.puts("  fetching #{name}")
        URI.parse(url).open("rb") { |remote| IO.copy_stream(remote, target) }
        target
      end

      def harvest(wanted)
        missing = wanted.reject { |row| File.exist?(wav_path(row["path"])) }
        return 0 if missing.empty?

        @archive ? from_archive(missing) : from_shards(missing)
      end

      def from_archive(missing)
        clips = File.join(File.dirname(archive_tsv), "clips")
        missing.count { |row| transcode(File.join(clips, File.basename(row["path"])), wav_path(row["path"])) }
      end

      def from_shards(missing)
        missing.group_by { |row| row["_bucket"] }.sum do |bucket, rows|
          names = rows.to_h { |row| [File.basename(row["path"]), row["path"]] }
          shards(bucket).sum { |shard| unpack(bucket, shard, names) }
        end
      end

      def shards(bucket)
        listing = URI.parse("https://huggingface.co/api/datasets/#{@repo}/tree/main/audio/#{LOCALE}/#{bucket}").read
        JSON.parse(listing).filter_map { |entry| File.basename(entry["path"]) if entry["type"] == "file" }.sort
      end

      def unpack(bucket, shard, names)
        tar = download("#{base_url}/audio/#{LOCALE}/#{bucket}/#{shard}", shard)
        stage = File.join(@work, bucket)
        FileUtils.mkdir_p(stage)
        converted = File.open(tar, "rb") { |io| take(io, stage, names) }

        FileUtils.rm_rf(stage)
        FileUtils.rm_f(tar)
        converted
      end

      def take(io, stage, names)
        Gem::Package::TarReader.new(io).sum do |entry|
          name = File.basename(entry.full_name)
          clip = names[name]
          next 0 if clip.nil? || !entry.file?

          source = File.join(stage, name)
          File.binwrite(source, entry.read)
          converted = transcode(source, wav_path(clip)) ? 1 : 0
          FileUtils.rm_f(source)
          converted
        end
      end

      def wav_path(clip) = File.join(@root, "audio", "#{File.basename(clip.to_s, ".*")}.wav")

      def transcode(source, target)
        return false if File.exist?(target)

        _, status = Open3.capture2e(
          "ffmpeg",
          "-y",
          "-loglevel",
          "error",
          "-i",
          source.to_s,
          "-ac",
          "1",
          "-ar",
          RATE.to_s,
          target
        )
        status.success?
      end

      def write(clips)
        payload = {
          "source" => "#{@release} (#{@archive ? "official release" : @repo})",
          "license" => LICENSE,
          "filter" => FILTER,
          "role" => ROLE,
          "sample_rate" => RATE,
          "n_clips" => clips.length,
          "n_speakers" => speakers(clips),
          "clips" => clips.sort_by { |row| row["path"] }.to_h { |row| [File.basename(row["path"]), clip(row)] }
        }

        File.write(File.join(@root, "manifest.json"), JSON.pretty_generate(payload))
      end

      def clip(row)
        {
          "speaker" => row["client_id"],
          "gender" => row["gender"],
          "age" => row["age"],
          "accent" => row["accents"],
          "sentence" => row["sentence"],
          "path" => "data/#{DIR}/audio/#{File.basename(row["path"], ".*")}.wav"
        }
      end

      def report(clips, converted)
        @io&.puts("  corpus_cv: #{clips.length} clips, #{speakers(clips)} speakers, #{converted} transcoded")
        {clips: clips.length, speakers: speakers(clips), converted: converted}
      end
    end
  end
end
