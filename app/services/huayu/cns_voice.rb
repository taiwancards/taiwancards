# frozen_string_literal: true

module Huayu
  class CnsVoice
    DATA = JsonData.new("huayu/cns_voice.json")
    DIRECTORY = "cns_voice"
    ATTRIBUTION = "數位發展部，CNS11643中文標準交換碼全字庫網站"
    VOICES = %w[female male].freeze
    KEY = /\A[a-z]{1,6}[1-5]?\z/
    NEUTRAL = "˙"

    Clip = Data.define(:voice, :key, :zhuyin)

    class << self
      def for(zhuyin, voice: nil)
        key = table[normalize(zhuyin)]
        return nil if key.nil?

        Clip.new(voice: pick(voice, key), key: key, zhuyin: normalize(zhuyin))
      end

      def alternating(zhuyin, index)
        self.for(zhuyin, voice: VOICES[index.to_i % VOICES.length])
      end

      def clip_path(voice, key)
        return nil unless VOICES.include?(voice) && KEY.match?(key.to_s)

        path = root.join("audio", voice, filename(voice, key))
        path.exist? ? path : nil
      end

      def clip_url(voice, key)
        return nil unless VOICES.include?(voice) && KEY.match?(key.to_s)

        base = base_url
        return Rails.application.routes.url_helpers.cns_clip_path(voice, key) if base.nil?

        "#{base}/#{DIRECTORY}/audio/#{voice}/#{filename(voice, key)}"
      end

      PLACEHOLDER = "aaaaaa"

      def clip_url_template(voice)
        return nil unless VOICES.include?(voice)

        base = base_url
        if base.nil?
          path = Rails.application.routes.url_helpers.cns_clip_path(voice, PLACEHOLDER)
          return path.sub(PLACEHOLDER, "%s")
        end

        "#{base}/#{DIRECTORY}/audio/#{voice}/#{voice[0].upcase}_%s.mp3"
      end

      def covers?(zhuyin) = table.key?(normalize(zhuyin))

      def available? = table.any?

      def size = table.size

      def table = DATA.value

      def base_url
        return @base_url if defined?(@base_url)

        @base_url = ENV["MEDIA_BASE_URL"].presence&.chomp("/")
      end

      def reset!
        DATA.reset!
        remove_instance_variable(:@base_url) if defined?(@base_url)
      end

      private

      def root = AppData.media_path(DIRECTORY)

      def filename(voice, key) = "#{voice[0].upcase}_#{key}.mp3"

      def pick(voice, key)
        return voice if VOICES.include?(voice)

        VOICES.find { |candidate| clip_path(candidate, key) } || VOICES.first
      end

      def normalize(zhuyin)
        text = zhuyin.to_s.strip.delete(" ")
        return text if text.start_with?(NEUTRAL) || !text.include?(NEUTRAL)

        NEUTRAL + text.delete(NEUTRAL)
      end
    end
  end
end
