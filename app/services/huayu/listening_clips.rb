# frozen_string_literal: true

module Huayu
  class ListeningClips
    DATA = JsonData.new("listening/manifest.json", root: :media, watch: true)

    Row = Data.define(:text, :level, :clip, :en, :ru, :emoji, :emoji_word, :emoji_category) do
      def translation(locale) = locale.to_s == "ru" ? (ru.presence || en) : en

      def emoji? = emoji.present?
    end

    class << self
      def all
        payload
      end

      def index
        @index ||= payload.index_by(&:text)
      end

      def for_text(text)
        index[text]
      end

      def pool(max_level:)
        payload.select { |row| row.level <= max_level }
      end

      def with_emoji(max_level:)
        pool(max_level:).select(&:emoji?)
      end

      def available? = payload.any?

      def clip_url(clip)
        base = ENV["MEDIA_BASE_URL"].presence&.chomp("/")
        return "#{base}/listening/audio/#{clip}" if base

        Rails.application.routes.url_helpers.listening_clip_path(clip.delete_suffix(".mp3"))
      end

      def reset!
        DATA.reset!
        remove_instance_variable(:@payload) if defined?(@payload)
        @manifest = nil
        @index = nil
      end

      private

      def payload
        manifest = DATA.value
        return @payload if defined?(@payload) && @manifest.equal?(manifest)

        @manifest = manifest
        @index = nil
        @payload = build(manifest).freeze
      end

      def build(manifest)
        Array(manifest["clips"]).map do |row|
          Row.new(
            text: row["text"],
            level: row["level"].to_i,
            clip: row["clip"],
            en: row["en"],
            ru: row["ru"],
            emoji: row["emoji"],
            emoji_word: row["emoji_word"],
            emoji_category: row["emoji_category"]
          )
        end
      end
    end
  end
end
