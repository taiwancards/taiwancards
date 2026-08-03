# frozen_string_literal: true

module Huayu
  class MoeAudio
    ATTRIBUTION = "中華民國教育部（Ministry of Education, R.O.C.）《國語辭典簡編本》"
    SOURCE_URL = "http://dict.concised.moe.edu.tw/"

    Clip = Data.define(:scope, :id, :head_ms, :zhuyin, :pinyin)

    SCOPES = {"words" => "moe_audio_words", "chars" => "moe_audio"}.freeze
    CLIP_ID = /\A[0-9A-Z]{4,}\z/

    class << self
      def for(text, zhuyin: nil)
        text = text.to_s.strip
        return nil if text.blank?

        SCOPES.each_key do |scope|
          readings = index(scope)[text]
          next if readings.blank?

          pick = choose(readings, zhuyin)
          next if pick.nil?

          return Clip.new(
            scope:,
            id: pick["id"],
            head_ms: pick["head_ms"],
            zhuyin: pick["zhuyin"],
            pinyin: pick["pinyin"]
          )
        end

        nil
      end

      def readings(text)
        text = text.to_s.strip
        return [] if text.blank?

        SCOPES.each_key do |scope|
          found = index(scope)[text]
          return found if found.present?
        end

        []
      end

      def clip_path(scope, id)
        return nil unless SCOPES.key?(scope)
        return nil unless CLIP_ID.match?(id.to_s)

        path = root(scope).join("audio", "#{id}.opus")
        path.exist? ? path : nil
      end

      def clip_url(scope, id)
        return nil unless SCOPES.key?(scope)
        return nil unless CLIP_ID.match?(id.to_s)

        base = base_url
        return Rails.application.routes.url_helpers.moe_clip_path(scope, id) if base.nil?

        "#{base}/#{SCOPES.fetch(scope)}/audio/#{id}.opus"
      end

      def base_url
        return @base_url if defined?(@base_url)

        @base_url = ENV["MEDIA_BASE_URL"].presence&.chomp("/")
      end

      def notice_path
        SCOPES.each_key do |scope|
          candidate = root(scope).join("notice.pdf")
          return candidate if candidate.exist?
        end

        nil
      end

      def notice?
        notice_path.present?
      end

      def version
        @version ||= SCOPES.keys.filter_map { |scope| manifest(scope)["version"] }.first
      end

      def available?
        SCOPES.keys.any? { |scope| index(scope).any? }
      end

      def reset!
        @manifests = nil
        @version = nil
        remove_instance_variable(:@base_url) if defined?(@base_url)
      end

      private

      def root(scope)
        AppData.media_path(SCOPES.fetch(scope))
      end

      def manifest(scope)
        @manifests ||= {}
        @manifests[scope] ||= begin
          file = root(scope).join("index.json")
          file.exist? ? JSON.parse(file.read) : {}
        rescue JSON::ParserError
          {}
        end
      end

      def index(scope)
        manifest(scope)["entries"] || {}
      end

      def choose(readings, zhuyin)
        return readings.one? ? readings.first : nil if zhuyin.blank?

        wanted = normalize(zhuyin)
        readings.find { |reading| normalize(reading["zhuyin"]) == wanted }
      end

      def normalize(value)
        value.to_s.gsub(/[[:space:]　]/, "")
      end
    end
  end
end
