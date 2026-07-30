# frozen_string_literal: true

module Pronunciation
  class Focus
    MIN_ATTEMPTS = 4
    PART_OF_CODE = {
      "tone" => "tone",
      "initial" => "initial",
      "sibilant" => "initial",
      "medial" => "medial",
      "vowel" => "final",
      "coda" => "final"
    }.freeze

    PART_FIELDS = {
      "initial" => %w[vot_ms centroid_ratio],
      "medial" => %w[f2_ratio],
      "final" => %w[f1_ratio f2_ratio f2_end_ratio nasal_ratio_tail],
      "tone" => %w[tone_range tone_slope]
    }.freeze

    INITIAL_CLASS = {
      "initials_plosive" => %w[b p d t g k],
      "initials_affricate" => %w[z c zh ch j q],
      "initials_fricative" => %w[f s sh x h r],
      "initials_nasal_lateral" => %w[m n l]
    }.freeze

    CODE_SECTION = {
      "initial.under_aspirated" => "aspiration",
      "initial.over_aspirated" => "aspiration",
      "sibilant.too_front" => "sibilants",
      "sibilant.too_back" => "sibilants",
      "coda.ng_for_n" => "coda_a",
      "coda.n_for_ng" => "coda_a"
    }.freeze

    def initialize(user, locale: I18n.locale, drills: Drills.instance)
      @user = user
      @locale = locale
      @drills = drills
      @coach = Coach.new(locale:)
      @verdict = Verdict.new
    end

    def weaknesses(limit: 3)
      buckets
        .values
        .select { |b| b[:n] >= MIN_ATTEMPTS }
        .map { |b| present(b) }
        .sort_by { |row| -row["priority"] }
        .first(limit)
    end

    def practiced? = skills.any?

    def summary
      return nil if skills.empty?

      {
        "syllables" => skills.length,
        "attempts" => skills.sum(&:n),
        "mastered" => skills.count(&:mastered?),
        "average" => average
      }
    end

    private

    def average
      scored = skills.select { |s| s.ewma_overall }
      return nil if scored.empty?

      (scored.sum { |s| s.ewma_overall * s.n } / scored.sum(&:n)).round
    end

    def skills
      @skills ||= SyllableSkill.where(user: @user).where(n: 1..).to_a
    end

    def buckets
      @buckets ||= begin
        acc = {}
        skills.each do |skill|
          descriptors(skill).each do |descriptor|
            part = descriptor["id"]
            score = skill.send(:"ewma_#{part}")
            next if score.nil?

            bucket = acc[[part, descriptor["zhuyin"]]] ||= blank(part, descriptor)
            bucket[:n] += skill.n
            bucket[:sum] += score * skill.n
            bucket[:keys] << [skill.syllable_key, score]
            bucket[:trend] << skill.trend if skill.trend
            merge_errors(bucket, skill, part)
            merge_z(bucket, skill, part)
          end
        end

        acc
      end
    end

    def blank(part, descriptor)
      {
        part: part,
        descriptor: descriptor,
        n: 0,
        sum: 0.0,
        keys: [],
        trend: [],
        errors: Hash.new(0),
        z: Hash.new { |h, k| h[k] = [0.0, 0] }
      }
    end

    def descriptors(skill)
      zhuyin = Acoustic::Syllables.zhuyin[skill.syllable_key]
      return [] if zhuyin.blank?

      parts = Parts.describe(zhuyin).select { |p| p["present"] }
      return parts if skill.tone.zero?

      parts + [{"id" => "tone", "zhuyin" => AcousticBackend::TONE_MARKS[skill.tone], "pinyin" => skill.tone.to_s}]
    rescue StandardError
      []
    end

    def merge_errors(bucket, skill, part)
      SyllableSkill::ERROR_CODES.each_with_index do |code, index|
        count = skill.error_counts[index].to_i
        next if count.zero?
        next unless PART_OF_CODE[code.split(".").first] == part

        bucket[:errors][code] += count
      end
    end

    def merge_z(bucket, skill, part)
      (PART_FIELDS[part] || []).each do |field|
        i = SyllableSkill::TRACKED.index(field)
        next if i.nil?

        count = skill.z_n[i].to_i
        next if count.zero?

        bucket[:z][field][0] += skill.z_sum[i].to_f
        bucket[:z][field][1] += count
      end
    end

    def present(bucket)
      score = (bucket[:sum] / bucket[:n]).round
      level = @verdict.level(bucket[:part], score)
      code = bucket[:errors].max_by { |_, count| count }&.first
      descriptor = bucket[:descriptor]

      {
        "part" => bucket[:part],
        "zhuyin" => descriptor["zhuyin"],
        "pinyin" => descriptor["pinyin"],
        "ipa" => descriptor["ipa"],
        "label" => I18n.t("pron.parts.#{bucket[:part]}", locale: @locale),
        "score" => score,
        "level" => level,
        "n" => bucket[:n],
        "trend" => trend_of(bucket),
        "cue" => @coach.part(descriptor, score, level, code || "near", {})["cue"],
        "problem" => code && I18n.t("pron.codes.#{code}", locale: @locale, **defaults(descriptor)),
        "advice" => code && I18n.t("pron.fixes.#{code}", locale: @locale, **defaults(descriptor)),
        "bias" => bias(bucket),
        "keys" => bucket[:keys].sort_by(&:last).first(6).map(&:first),
        "section" => section_for(bucket, code),
        "priority" => priority(bucket[:part], score, bucket[:n])
      }.compact
    end

    def defaults(descriptor)
      {
        initial: descriptor["pinyin"],
        pair: Acoustic::Phonology::ASPIRATION_PAIRS[descriptor["pinyin"]],
        ipa: descriptor["ipa"],
        tone: descriptor["pinyin"],
        got: "?",
        medial: descriptor["pinyin"],
        coda: descriptor["pinyin"],
        final: descriptor["pinyin"],
        nucleus: descriptor["pinyin"],
        series: nil,
        counterparts: nil,
        range: nil,
        slope: nil
      }
    end

    def trend_of(bucket)
      return nil if bucket[:trend].empty?

      (bucket[:trend].sum / bucket[:trend].length).round(1)
    end

    def bias(bucket)
      bucket[:z]
        .filter_map { |field, (sum, count)|
          next if count < SyllableSkill::CONFIDENT_AT

          mean = sum / count
          {"field" => field, "z" => mean.round(2)} if mean.abs >= SyllableSkill::SYSTEMATIC_Z
        }
        .sort_by { |row| -row["z"].abs }
        .first(2)
        .presence
    end

    def priority(part, score, n)
      gap = [@verdict.bounds(part)["green"] - score, 0].max
      (gap * Math.log(1 + n)).round(2)
    end

    def section_for(bucket, code)
      candidates = [
        CODE_SECTION[code],
        (bucket[:part] == "tone") ? "tone_#{bucket[:descriptor]["pinyin"]}" : nil,
        (bucket[:part] == "initial") ? INITIAL_CLASS
          .find { |_, list| list.include?(bucket[:descriptor]["pinyin"]) }
          &.first : nil,
        (bucket[:part] == "final") ? vowel_section(bucket[:descriptor]["pinyin"]) : nil
      ].compact

      candidates.find { |id| @drills.section(id) }
    end

    def vowel_section(pinyin)
      letter = pinyin.to_s[0]
      letter = "v" if letter == "ü"
      %w[a o e i u v].include?(letter) ? "vowel_#{letter}" : nil
    end
  end
end
