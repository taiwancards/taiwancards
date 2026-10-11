# frozen_string_literal: true

module Huayu
  class WordClips
    DATA = JsonData.new("word_clips/manifest.json", root: :media, watch: true)

    class << self
      def for_text(text) = index[text]

      def clip_url(clip)
        base = ENV["MEDIA_BASE_URL"].presence&.chomp("/")
        return "#{base}/word_clips/audio/#{clip}" if base

        Rails.application.routes.url_helpers.word_clip_path(clip.delete_suffix(".mp3"))
      end

      def reset!
        DATA.reset!
        @manifest = nil
        @index = nil
      end

      private

      def index
        manifest = DATA.value
        return @index if @index && @manifest.equal?(manifest)

        @manifest = manifest
        @index = manifest.fetch("clips", {}).transform_values { |row| row["clip"] }.compact.freeze
      end
    end
  end
end
