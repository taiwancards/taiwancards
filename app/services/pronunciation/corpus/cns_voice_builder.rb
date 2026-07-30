# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"

module Pronunciation
  module Corpus
    class CnsVoiceBuilder
      DIR = "corpus_cns"
      RATE = 22_050
      SOURCE = "cns_voice"
      NORM = "taiwan"
      SPEAKERS = {"female" => "cns_f", "male" => "cns_m"}.freeze
      DESCRIPTION = "CNS11643 syllable recordings, two studio voices, isolated citation forms"

      def initialize(io: nil, base: nil)
        @io = io
        @root = (base && File.join(base, DIR)) || AppData.media_path("pronunciation/#{DIR}").to_s
        @link = File.join(TemplateStore.instance.root, DIR)
      end

      def build!
        return report(0, 0) unless Huayu::CnsVoice.available?

        FileUtils.mkdir_p(File.join(@root, "audio"))
        link!
        tokens = Hash.new { |hash, key| hash[key] = [] }
        converted = 0

        Huayu::CnsVoice.table.each do |zhuyin, key|
          syllable = key.match?(/\d\z/) ? key : "#{key}1"

          SPEAKERS.each do |voice, speaker|
            source = Huayu::CnsVoice.clip_path(voice, key)
            next if source.nil?

            name = "#{voice}_#{key}.wav"
            converted += 1 if transcode(source, File.join(@root, "audio", name))
            tokens[syllable] << token(name, speaker, zhuyin)
          end
        end

        write(tokens)
        report(tokens.size, converted)
      end

      private

      def link!
        return if File.exist?(@link) || File.symlink?(@link)

        FileUtils.ln_s(Pathname(@root).relative_path_from(Pathname(File.dirname(@link))).to_s, @link)
      end

      def token(name, speaker, zhuyin)
        {
          "source" => SOURCE,
          "index" => 0,
          "n_syllables" => 1,
          "transcript" => zhuyin,
          "speaker" => speaker,
          "norm" => NORM,
          "path" => "data/#{DIR}/audio/#{name}"
        }
      end

      def transcode(source, target)
        return false if File.exist?(target) && File.mtime(target) >= File.mtime(source)

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

      def write(tokens)
        payload = {
          "sample_rate" => RATE,
          "norm" => NORM,
          "sources" => {SOURCE => DESCRIPTION},
          "tokens" => tokens.sort.to_h
        }
        File.write(File.join(@root, "manifest.json"), JSON.pretty_generate(payload))
      end

      def report(syllables, converted)
        @io&.puts("  cns voice: #{syllables} syllables, #{converted} clips transcoded into #{@root}")
        {syllables:, converted:}
      end
    end
  end
end
