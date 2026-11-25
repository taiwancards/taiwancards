# frozen_string_literal: true

module Huayu
  class ListeningClips
    DATA = JsonData.new("listening/manifest.json", root: :media, watch: true)
    EXCLUDED = JsonData.new("huayu/listening_excluded.json", default: [])

    Row = Data.define(:text, :level, :clip, :en, :ru, :vi, :de, :ind, :ja, :emoji, :emoji_word, :emoji_category) do
      def translations = Locales::STORED.to_h { |key| [key, public_send(key)] }

      def translation(locale) = Locales.sentence(translations, locale)

      def emoji? = emoji.present?
    end

    class << self
      def all
        payload
      end

      def index
        rows = payload
        @index ||= rows.index_by(&:text)
      end

      def for_text(text)
        index[text]
      end

      def by_clip(clip)
        rows = payload
        (@by_clip ||= rows.index_by(&:clip))[clip]
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
        EXCLUDED.reset!
        TranscriptCorrections.reset!
        remove_instance_variable(:@payload) if defined?(@payload)
        @manifest = nil
        @rejects_stamp = nil
        @index = nil
        @by_clip = nil
      end

      private

      def payload
        manifest = DATA.value
        stamp = rejects_stamp
        return @payload if defined?(@payload) && @manifest.equal?(manifest) && @rejects_stamp == stamp

        @manifest = manifest
        @rejects_stamp = stamp
        @index = nil
        @by_clip = nil
        @payload = build(manifest).freeze
      end

      def rejects_stamp
        path = SentenceRejectStore.path
        path.exist? ? path.mtime : nil
      end

      def withheld
        SentenceRejectStore
          .read
          .select { |entry| SentenceRejectStore.unconditional?(entry.reason) }
          .to_set(&:text)
          .merge(EXCLUDED.value)
      end

      def build(manifest)
        hidden = withheld
        Array(manifest["clips"]).filter_map do |row|
          text = TranscriptCorrections.apply(row["text"])
          next if hidden.include?(row["text"]) || hidden.include?(text)

          Row.new(
            text:,
            level: row["level"].to_i,
            clip: row["clip"],
            en: row["en"],
            ru: row["ru"],
            vi: row["vi"],
            de: row["de"],
            ind: row["ind"],
            ja: row["ja"],
            emoji: row["emoji"],
            emoji_word: row["emoji_word"],
            emoji_category: row["emoji_category"]
          )
        end
      end
    end
  end
end
