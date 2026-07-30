# frozen_string_literal: true

module Huayu
  class ToneDrill
    MARKS = {"ˊ" => 2, "ˇ" => 3, "ˋ" => 4}.freeze
    NEUTRAL = "˙"
    TONES = [1, 2, 3, 4].freeze
    PER_TONE = 6

    def initialize(user: nil, rng: Random.new)
      @user = user
      @rng = rng
    end

    def items(count: 24)
      pool = candidates
      return [] if pool.values.any?(&:empty?)

      per = [(count / TONES.size.to_f).ceil, PER_TONE].max
      picked = TONES.flat_map { |tone| pool.fetch(tone).sample(per, random: @rng) }
      picked.shuffle(random: @rng).first(count).each_with_index.map { |item, index| alternate(item, index) }
    end

    def self.tone_of(zhuyin)
      text = zhuyin.to_s.strip
      return nil if text.empty? || text.start_with?(NEUTRAL)

      MARKS[text[-1]] || 1
    end

    private

    def alternate(item, index)
      clip = CnsVoice.alternating(item[:zhuyin], index)
      return item if clip.nil?

      url = CnsVoice.clip_url(clip.voice, clip.key)
      return item if url.nil?

      item.merge(clip: url, stop_ms: nil, voice: clip.voice)
    end

    def candidates
      @candidates ||= begin
        buckets = TONES.index_with { [] }

        Lexeme
          .visible_to(@user)
          .where(kind: :character)
          .where("lexemes.readings->>'zhuyin' IS NOT NULL")
          .curriculum_order
          .limit(1_200)
          .each do |lexeme|
            zhuyin = lexeme.readings["zhuyin"].to_s.strip
            tone = self.class.tone_of(zhuyin)
            next if tone.nil?

            clip = Huayu::MoeAudio.for(lexeme.text, zhuyin:)
            next if clip.nil?

            buckets[tone] <<
              {
                text: lexeme.text,
                zhuyin:,
                pinyin: lexeme.readings["pinyin"],
                meaning: lexeme.meaning(I18n.locale),
                tone:,
                clip: MoeAudio.clip_url(clip.scope, clip.id),
                stop_ms: clip.head_ms
              }
          end

        buckets
      end
    end
  end
end
