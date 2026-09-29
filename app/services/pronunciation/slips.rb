# frozen_string_literal: true

module Pronunciation
  module Slips
    NOTHING = "∅"
    RIME = %w[medial final].freeze

    module_function

    def between(expected_key, expected_zhuyin, heard_key, heard_zhuyin)
      want = sound(expected_key, expected_zhuyin)
      got = sound(heard_key, heard_zhuyin)
      return [] if want.nil? || got.nil?

      [initial(want, got), rime(want, got), tone(want, got)].compact
    end

    def sound(key, zhuyin)
      syllable, tone = Acoustic::Syllables.parse_key(key.to_s)
      bare = zhuyin.to_s.delete(Parts::TONE_CHARS).strip
      return nil if syllable.nil? || bare.empty?

      parts = Parts.describe(bare).to_h { |part| [part["id"], part] }
      {pinyin: spelled(syllable, bare), tone:, parts:}
    end

    def initial(want, got)
      a = want[:parts]["initial"]
      b = got[:parts]["initial"]
      return nil if a["zhuyin"] == b["zhuyin"]

      slip("initial", arrow(a["zhuyin"], b["zhuyin"]), arrow(a["pinyin"], b["pinyin"]))
    end

    def rime(want, got)
      changed = RIME.reject { |id| written(want, id) == written(got, id) }
      return nil if changed.empty?

      zhuyin = arrow(changed.sum("") { |id| written(want, id) }, changed.sum("") { |id| written(got, id) })
      slip(changed.last, zhuyin, arrow(want[:pinyin], got[:pinyin]))
    end

    def tone(want, got)
      return nil if want[:tone] == got[:tone]

      marks = AcousticBackend::TONE_MARKS
      slip("tone", arrow(marks[want[:tone]], marks[got[:tone]]), arrow(want[:tone], got[:tone]))
    end

    def written(sound, id)
      part = sound[:parts][id]
      return "" if part.nil? || !part["present"] || part["empty_rime"]

      part["zhuyin"].to_s
    end

    def spelled(syllable, bare)
      [syllable, syllable.tr("v", "ü"), syllable.sub("u", "ü")].uniq.find { |candidate|
        Huayu::Zhuyin.from_pinyin(candidate).to_s.delete(Parts::TONE_CHARS) == bare
      } ||
        syllable
    end

    def arrow(from, to) = "#{from.to_s.presence || NOTHING}→#{to.to_s.presence || NOTHING}"

    def slip(part, zhuyin, pinyin) = {"part" => part, "zhuyin" => zhuyin, "pinyin" => pinyin}
  end
end
