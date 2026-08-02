# frozen_string_literal: true

module Huayu
  class PhoneticsDrill
    STAGES = %w[consonants vowels finals syllables].freeze
    CHOICES = 4
    CANDIDATES = 5
    SYLLABLE_POOL = 600
    SYLLABLE_KEEP = 150

    MEDIALS = %w[ㄧ ㄨ ㄩ].freeze
    SIMPLE_VOWELS = %w[ㄚ ㄛ ㄜ ㄝ].freeze
    GLIDE_INITIALS = %w[y w].freeze

    HARD_CASES = {
      "iu" => "iu",
      "ui" => "ui",
      "un" => "un",
      "ong" => "ong",
      "ie" => "ie",
      "ue" => "ue",
      "er" => "er"
    }.freeze

    EMPTY_RIME = %w[zhi chi shi ri zi ci si].freeze

    def initialize(locale: I18n.locale)
      @locale = locale.to_s
    end

    def items(stage)
      case stage
      when "consonants"
        parts(consonants)
      when "vowels"
        parts(vowels)
      when "finals"
        parts(finals)
      else
        syllables
      end
    end

    def stage_counts
      STAGES.index_with { |stage| items(stage).size }
    end

    private

    def consonants
      Phonetics.initials.reject { |row| GLIDE_INITIALS.include?(row["pinyin"]) }
    end

    def vowels
      Phonetics.finals.select { |row| MEDIALS.include?(row["zhuyin"]) || SIMPLE_VOWELS.include?(row["zhuyin"]) }
    end

    def finals
      seen = []
      Phonetics.finals.reject { |row|
        zhuyin = row["zhuyin"].to_s
        next true if zhuyin.blank?
        next true if MEDIALS.include?(zhuyin) || SIMPLE_VOWELS.include?(zhuyin)
        next true if seen.include?(zhuyin)

        seen << zhuyin
        false
      }
    end

    def parts(rows)
      pool = rows.map { |row| row["zhuyin"].to_s }.uniq

      rows.map do |row|
        example = row["example"] || {}
        {
          id: "#{row["pinyin"]}|#{row["zhuyin"]}",
          zhuyin: row["zhuyin"].to_s,
          pinyin: row["pinyin"].to_s,
          ipa: row["ipa"].to_s,
          hint: localized(row),
          hanzi: example["hanzi"].to_s,
          hanziZhuyin: example["zhuyin"].to_s.presence || zhuyin_for(example["pinyin"]),
          hanziPinyin: example["pinyin"].to_s,
          hanziGloss: localized(example),
          note: row["note"].to_s,
          distractors: distractors(pool, row["zhuyin"].to_s, rows)
        }
      end
    end

    def distractors(pool, correct, rows)
      ranked = (pool - [correct]).sort_by { |zhuyin| [-affinity(correct, zhuyin), rand] }
      ranked.first(CANDIDATES).map { |zhuyin|
        {zhuyin:, pinyin: rows.find { |row| row["zhuyin"] == zhuyin }["pinyin"].to_s}
      }
    end

    def affinity(a, b)
      score = (a.chars & b.chars).size * 2
      score += 3 if a[0] == b[0]
      score += 2 if a[-1] == b[-1]
      score += 4 if confusable?(a[0], b[0])
      score += 3 if confusable?(a[-1], b[-1])
      score += 1 if a.length == b.length
      score
    end

    def confusable?(a, b)
      a != b && Array(ZhuyinTrainer::CONFUSABLE[a]).include?(b)
    end

    def syllables
      rows = syllable_rows
      pool = rows.map { |row| row.slice(:bare, :base) }.uniq

      rows.map do |row|
        row.except(:bare, :base, :tone).merge(distractors: syllable_distractors(pool, row))
      end
    end

    def syllable_rows
      scope = Lexeme
        .unrestricted
        .where(kind: :character)
        .where("readings->>'zhuyin' <> '' AND readings->>'pinyin' <> ''")
        .curriculum_order
        .limit(SYLLABLE_POOL)

      seen = Set.new
      rows = scope.filter_map { |lexeme| syllable_row(lexeme, seen) }
      hard, plain = rows.partition { |row| row[:hard] }
      (hard + plain.sample(SYLLABLE_KEEP - hard.size).to_a).first(SYLLABLE_KEEP)
    end

    def syllable_row(lexeme, seen)
      pinyin = lexeme.readings["pinyin"].to_s.strip
      zhuyin = lexeme.readings["zhuyin"].to_s.strip
      return if pinyin.blank? || zhuyin.blank? || pinyin.include?(" ")

      bare = zhuyin.delete(ReadingForms::ZHUYIN_TONES)
      return unless seen.add?(bare)

      plain = ReadingForms.plain_pinyin(pinyin).to_s
      {
        id: zhuyin,
        zhuyin:,
        pinyin:,
        ipa: "",
        hint: "",
        hanzi: lexeme.text,
        hanziZhuyin: zhuyin,
        hanziPinyin: pinyin,
        hanziGloss: lexeme.meanings[@locale].presence || lexeme.meanings["en"].to_s,
        note: "",
        hard: hard_case(plain),
        bare:,
        base: ReadingForms.marked_pinyin(pinyin, nil),
        tone: Zhuyin.tone(pinyin)
      }
    end

    def hard_case(plain)
      return "empty" if EMPTY_RIME.include?(plain)
      return "glide" if plain.start_with?("y", "w")

      HARD_CASES.keys.find { |pattern| plain.end_with?(pattern) }
    end

    def syllable_distractors(pool, row)
      ranked = pool
        .reject { |cand| cand[:bare] == row[:bare] }
        .sort_by { |cand| [-syllable_affinity(row, cand), rand] }

      ranked.first(CANDIDATES).map do |cand|
        {
          zhuyin: Zhuyin.apply_tone(cand[:bare], row[:tone]),
          pinyin: ReadingForms.marked_pinyin(cand[:base], row[:tone])
        }
      end
    end

    def syllable_affinity(row, cand)
      score = affinity(row[:bare], cand[:bare])
      score += 3 if cand[:base].chars.sort == row[:base].chars.sort
      score
    end

    def localized(row)
      (row[@locale].presence || row["en"]).to_s
    end

    def zhuyin_for(pinyin)
      return "" if pinyin.blank?

      Zhuyin.from_pinyin(pinyin).to_s.delete("˙")
    end
  end
end
