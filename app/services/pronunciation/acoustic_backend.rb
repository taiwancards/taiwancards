# frozen_string_literal: true

module Pronunciation
  class AcousticBackend
    MIN_SYLLABLE_MS = 70
    MAX_UTTERANCE_MS = 8000
    PER_SYLLABLE_MS = 900

    TONE_MARKS = {1 => "ˉ", 2 => "ˊ", 3 => "ˇ", 4 => "ˋ", 5 => "˙"}.freeze

    def initialize(store: TemplateStore.instance, verdict: Verdict.new, tonal: true, voice: nil, locale: I18n.locale)
      @store = store
      @verdict = verdict
      @tonal = tonal
      @voice = voice
      @locale = locale
      @coach = Coach.new(locale:)
    end

    attr_reader :tonal

    def health
      {"ok" => @store.available?, "backend" => "acoustic", "path" => @store.root}
    end

    def grade(audio:, text:, syllables:, takes: 1)
      return nil unless @store.available?

      samples, rate = decode(audio)
      return failure("unreadable") if samples.nil? || samples.empty?

      analysis = Acoustic::Features.analyze(samples, rate)
      expected = syllables.each_with_index.map { |target, index| resolve(target, index, syllables.length) }
      repeats = Acoustic::Takes.wanted(analysis, syllables.length, takes)
      heard = spans_for(analysis, expected, repeats)
      return failure(heard) if heard.is_a?(String)

      measured = measure_all(analysis, expected, heard)

      place_in_range(measured)
      normalize_tempo(measured)

      rankings = measured.map { |row| ranking_for(row) }
      graded = measured.each_with_index.map do |row, index|
        row[:absent] ? absent(row[:target], row[:key]) : score_one(row, rankings[index])
      end

      overall = aggregate(graded)
      {
        "takes" => heard.length,
        "syllables" => graded,
        "overall" => overall,
        "overall_level" => @verdict.level("overall", overall),
        "flow" => flow(analysis, heard.first, expected),
        "read" => read(measured, overall),
        "legend" => legend,
        "text" => text
      }.compact
    end

    private

    def failure(reason)
      {"status" => "retry", "reason" => reason}
    end

    def spans_for(analysis, expected, repeats)
      templates = expected.map { |row| row[:template] }
      count = expected.length

      if repeats > 1
        windows = Acoustic::Takes.runs_of(analysis).first(repeats)
        if windows.length == repeats
          taken = windows.filter_map { |window| Acoustic::Takes.spans_within(analysis, window, count) }
          return taken if taken.length == repeats
        end
      end

      once = segment(analysis, count, templates)
      once.is_a?(String) ? once : [once]
    end

    def measure_all(analysis, expected, takes)
      per_take = takes.map do |spans|
        expected.each_with_index.map { |row, index| measure_one(analysis, spans[index], row, index) }
      end

      return per_take.first if per_take.length < 2

      expected.each_index.map do |index|
        rows = per_take.filter_map { |take| take[index] unless take[index][:absent] }
        next per_take.first[index] if rows.empty?

        rows.first.merge(features: Acoustic::Consensus.merge(rows.map { |row| row[:features] }))
      end
    end

    def segment(analysis, count, templates)
      return "no_syllables" if count.zero?

      low, high = Acoustic::Features.utterance_bounds(analysis, count)
      return "no_speech" unless low && high && high > low
      return "too_long" if (high - low + 1) * Acoustic::Features::HOP_MS > allowance(count)

      Acoustic::Features.syllable_spans(analysis, count) ||
        aligner.spans(analysis, templates) ||
        Acoustic::Features.forced_spans(analysis, count) ||
        "no_speech"
    end

    def allowance(count) = [MAX_UTTERANCE_MS, count * PER_SYLLABLE_MS].max

    def flow(analysis, spans, expected)
      coached(Acoustic::Junctions.score(analysis, spans, expected.map { |row| row[:key] }, store: @store))
    end

    def read(measured, overall)
      coached(Acoustic::Verification.check(measured, overall:, store: @store, analyzer:))
    end

    def coached(block)
      return nil if block.nil?

      block.merge({"note" => @coach.advisory(block["code"]), "advice" => @coach.fix(block["code"])}.compact)
    end

    def aligner = @aligner ||= Acoustic::Alignment.new

    def resolve(target, index, total)
      key = SyllableKey.for(target, store: @store)
      norm = @store.norm_for(position: index, total: total)
      {target:, key:, norm:, template: @store.template(key, norm) || @store.template(key, TemplateStore::CITATION)}
    end

    def measure_one(analysis, span, row, index)
      template = row[:template]
      return {absent: true, target: row[:target], key: row[:key]} if template.nil? || span.nil?
      return {absent: true, target: row[:target], key: row[:key]} if short?(span)

      features = Acoustic::Features.extract(
        analysis,
        span,
        initial: template.dig("structure", "initial"),
        utterance_initial: index.zero?,
        f0_reference: speaker_reference_hz
      )
      features["f0_register"] = register(features)
      Acoustic::Vowel.place(features, speaker_reference_hz)
      row.merge(features:, index:)
    end

    def short?(span) = (span[1] - span[0]) * Acoustic::Features::HOP_MS < MIN_SYLLABLE_MS

    def speaker_reference_hz
      return nil unless @voice&.calibrated?

      @voice.reference_hz
    end

    def place_in_range(measured)
      rows = measured.reject { |row| row[:absent] }
      place_vowels(rows)
      align_timbre(rows)
      place_neighbours(rows)
      placed = Acoustic::Register.from_utterance(
        rows.map { |row| row[:features]["f0_ref_hz"] },
        rows.map { |row| row[:template].dig("f0_register", "median") }
      )
      return if placed.empty?

      heard = placed.compact.length
      rows.each_with_index do |row, index|
        row[:features]["f0_register"] ||= placed[index]
        row[:features]["n_register"] = heard
      end
    end

    def align_timbre(rows)
      Acoustic::Timbre.align(
        rows.map { |row| [row[:features]["mfcc"], row[:template]&.dig("mfcc", "center")] }
      )
    end

    def place_neighbours(rows)
      tones = rows.map { |row| row[:template]&.fetch("tone", nil).to_i }
      onsets = rows.map { |row| row[:template]&.dig("structure", "initial") }
      rows.each_with_index do |row, index|
        row[:features]["tone_before"] = index.zero? ? Acoustic::ContextNorms::EDGE : tones[index - 1]
        row[:features]["tone_after"] = tones[index + 1] || Acoustic::ContextNorms::EDGE
        row[:features]["onset_after"] = onsets[index + 1]
      end
    end

    def place_vowels(rows)
      return if speaker_reference_hz

      centre = Acoustic::Vowel.speaker_hz(rows.map { |row| row[:features] })
      return if centre.nil?

      rows.each { |row| Acoustic::Vowel.place(row[:features], centre) }
    end

    TEMPO_FIELDS = %w[voiced_ms duration_ms].freeze
    TEMPO_RANGE = (0.6..1.6)
    TEMPO_DEADBAND = 0.1

    def normalize_tempo(measured)
      rows = measured.reject { |row| row[:absent] }
      return if rows.length < 2

      spoken = rows.sum { |row| row[:features]["voiced_ms"].to_f }
      expected = rows.sum { |row| row[:template].dig("voiced_ms", "median").to_f }
      return unless spoken.positive? && expected.positive?

      tempo = (spoken / expected).clamp(TEMPO_RANGE.min, TEMPO_RANGE.max)
      return if (tempo - 1.0).abs < TEMPO_DEADBAND

      rows.each do |row|
        TEMPO_FIELDS.each do |field|
          value = row[:features][field]
          row[:features][field] = value / tempo if value
        end
      end
    end

    def ranking_for(row)
      return [] if row[:absent] || !@tonal

      analyzer.rank_candidates(row[:features], row[:key], row[:norm])
    rescue StandardError
      []
    end

    def score_one(row, ranking = [])
      target = row[:target]
      key = row[:key]
      norm = row[:norm]
      template = row[:template]
      features = row[:features]
      index = row[:index]

      axes = analyzer.score_axes(features, template, template["norm"] || TemplateStore::CITATION)
      axes = axes.reject { |a| a["id"] == "tone" } unless @tonal

      scored = analyzer.part_scores(axes)
      weights = weights_for(key, template, norm, scored.map { |p| p["id"] })
      shares = Acoustic::Weights.shares(weights)
      overall = analyzer.weighted_overall(scored, weights)

      best = ranking.first&.fetch("key", nil) || (@tonal ? key : nil)
      evaluation = {"overall" => overall, "parts" => scored, "best_match" => best, "expected" => key}
      lead = analyzer.lead_in(features, template)

      @verdict.for_syllable(evaluation, expected: key).merge(
        "char" => target["char"],
        "pinyin" => target["pinyin"],
        "zhuyin" => target["zhuyin"],
        "key" => key,
        "index" => index,
        "tone" => template["tone"],
        "parts" => present_parts(scored, shares, zhuyin_of(target, template), template["tone"]),
        "contour" => contour(scored),
        "advisories" => advisories(axes, lead),
        "sounded_like" => confusion(key, best, scored),
        "deviations" => analyzer.deviations(features, template),
        "codes" => axes.map { |a| a["code"] }.reject { |code| code.end_with?(".ok") },
        "features" => digest(features, scored),
        "diagnostics" => diagnostics(features, axes, template, lead)
      )
    end

    def octave_folded?(features)
      hz = features["f0_ref_hz"].to_f
      return false unless @voice && hz > 50

      (@voice.octave_corrected(hz) - hz).abs > 1.0
    end

    def voice_digest
      return {"calibrated" => false} if @voice.nil?

      s = @voice.summary
      {
        "calibrated" => s[:calibrated],
        "tone" => s[:tone_calibrated],
        "f0" => [s[:f0_low], s[:f0_median], s[:f0_high]],
        "f3" => s[:f3_ref],
        "warp" => s[:warp],
        "tones" => s[:tones_measured],
        "span" => s[:tone_span_semitones],
        "excursion" => s[:tone_excursion_semitones],
        "frames" => s[:n_frames],
        "attempts" => s[:n_attempts]
      }
    end

    def diagnostics(features, axes, template, lead)
      {
        "voice" => voice_digest,
        "signal" => {
          "duration_ms" => features["duration_ms"]&.round,
          "voiced_ms" => features["voiced_ms"]&.round,
          "f0_ref_hz" => features["f0_ref_hz"]&.round(1),
          "f0_folded" => octave_folded?(features),
          "vot_ms" => features["vot_ms"]&.round(1),
          "vot_reliable" => features["vot_reliable"],
          "lead_ms" => lead&.dig("vars", "ms"),
          "takes" => features["n_takes"],
          "register" => features["f0_register"]&.round(2)
        },
        "template" => {
          "style" => template.dig("provenance", "style"),
          "tokens" => template.dig("provenance", "n_tokens"),
          "speakers" => template.dig("provenance", "n_speakers"),
          "confidence" => template.dig("provenance", "confidence")
        },
        "axes" => axes.map { |a| a.slice("id", "part", "z", "score", "ok", "code", "measured") },
        "fields" => analyzer.report(features, template)
      }
    end

    def confusion(key, best, scored)
      return nil if best.blank? || best == key

      syllable, = Acoustic::Syllables.parse_key(key)
      rival, = Acoustic::Syllables.parse_key(best)
      return nil if rival == syllable && !weak_part?(scored, "tone")
      return nil if rival != syllable && PART_ORDER.excluding("tone").none? { |id| weak_part?(scored, id) }

      @coach.confusion(key, best)
    end

    def weak_part?(scored, id)
      part = scored.find { |p| p["id"] == id }
      part.present? && @verdict.level(id, part["score"]) != "green"
    end

    PART_ORDER = %w[initial medial final tone].freeze

    def zhuyin_of(target, template)
      template["zhuyin"].presence || target["zhuyin"].to_s.delete(Parts::TONE_CHARS).presence
    end

    def percentages(shares)
      exact = shares.transform_values { |share| share * 100.0 }
      whole = exact.transform_values(&:floor)
      short = 100 - whole.values.sum
      return whole unless short.positive?

      exact.sort_by { |id, value| -(value - whole[id]) }.first(short).each { |id, _| whole[id] += 1 }
      whole
    end

    def present_parts(scored, shares, zhuyin, tone)
      by_id = scored.to_h { |p| [p["id"], p] }
      percent = percentages(shares)
      descriptors = Parts.describe(zhuyin) + [tone_descriptor(tone), timbre_descriptor(zhuyin)]

      descriptors.filter_map do |descriptor|
        id = descriptor["id"]
        next if id == "tone" && !@tonal

        part = by_id[id]
        level = if !descriptor["present"]
          "none"
        else
          part ? @verdict.level(id, part["score"]) : "gray"
        end

        descriptor.merge(
          @coach.part(
            descriptor,
            part&.fetch("score", nil),
            level,
            part&.fetch("code", nil) || "near",
            part&.fetch("vars", nil)
          ),
          "weight" => percent[id] || 0,
          "measured" => part.present?
        )
      end
    end

    def timbre_descriptor(zhuyin)
      {"id" => "timbre", "present" => zhuyin.present?, "zhuyin" => zhuyin, "pinyin" => nil, "ipa" => nil}
    end

    def tone_descriptor(tone)
      {"id" => "tone", "present" => tone.present?, "zhuyin" => TONE_MARKS[tone], "pinyin" => tone.to_s, "ipa" => nil}
    end

    def contour(scored)
      measured = scored.find { |p| p["id"] == "tone" }&.fetch("measured", nil)
      return nil if measured.blank? || measured["curve"].blank?

      measured.slice("curve", "reference", "sigma", "range", "slope", "register")
    end

    def advisories(axes, lead)
      notes = analyzer.advisories(axes).reject { |a| a["code"].to_s.end_with?(".ok") }
      notes += [lead].compact

      notes.filter_map do |a|
        note = @coach.advisory(a["code"], a["vars"])
        {"id" => a["id"], "score" => a["score"], "note" => note} if note
      end
    end

    def weights_for(key, template, norm, present)
      syllable, tone = Acoustic::Syllables.parse_key(key)
      return Acoustic::Weights::BASE.slice(*present) if syllable.nil?

      Acoustic::Weights.for_syllable(syllable, tone, present, profile: contrast_profile(key, norm))
    rescue StandardError
      Acoustic::Weights::BASE.slice(*present)
    end

    def contrast_profile(key, norm)
      syllable, tone = Acoustic::Syllables.parse_key(key)
      keys = ([key] + Acoustic::Syllables.confusion_set(syllable, tone)).uniq
      Acoustic::Contrasts.merged_profile(key, analyzer.candidate_templates(keys, norm))
    end

    def register(features)
      return nil unless @voice&.tone_calibrated?

      ref = @voice.reference_hz
      return nil unless ref && ref > 50 && features["f0_ref_hz"].to_f > 50

      12.0 * Math.log2(@voice.octave_corrected(features["f0_ref_hz"]) / ref)
    end

    def digest(features, scored)
      {
        "duration_ms" => features["duration_ms"].round,
        "f0_ref_hz" => features["f0_ref_hz"]&.round(1),
        "z" => scored.to_h { |p| [p["id"], p["z"]] }
      }
    end

    def legend
      @legend ||= Legend.new(verdict: @verdict, locale: @locale).rows
    end

    def absent(target, key)
      {
        "char" => target["char"],
        "pinyin" => target["pinyin"],
        "zhuyin" => target["zhuyin"],
        "key" => key,
        "overall" => nil,
        "level" => "gray",
        "color" => "gray",
        "fill" => 0,
        "cells" => {},
        "parts" => [],
        "rejected" => false,
        "unavailable" => true
      }
    end

    def aggregate(graded)
      scored = graded.filter_map { |s| s["overall"] }
      return nil if scored.empty?

      (scored.sum.to_f / scored.length).round
    end

    def analyzer
      @analyzer ||= Acoustic::Analyzer.new(@store)
    end

    def decode(audio)
      Recording.decode(audio)
    rescue StandardError
      [nil, nil]
    end
  end
end
