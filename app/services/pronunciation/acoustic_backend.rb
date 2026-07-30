# frozen_string_literal: true

module Pronunciation
  class AcousticBackend
    MIN_SYLLABLE_MS = 70
    MAX_UTTERANCE_MS = 8000

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

    def grade(audio:, text:, syllables:)
      return nil unless @store.available?

      samples, rate = decode(audio)
      return nil if samples.nil? || samples.empty?

      analysis = Acoustic::Features.analyze(samples, rate)
      spans = segment(analysis, syllables.length)
      return nil if spans.nil?

      graded = syllables.each_with_index.map do |target, index|
        grade_one(analysis, spans[index], target, index, syllables.length)
      end

      {
        "syllables" => graded,
        "overall" => aggregate(graded),
        "overall_level" => @verdict.level("overall", aggregate(graded)),
        "legend" => legend,
        "text" => text
      }
    end

    private

    def segment(analysis, count)
      return nil if count.zero?

      low, high = Acoustic::Features.speech_bounds(analysis)
      return nil unless low && high && high > low
      return nil if (high - low + 1) * Acoustic::Features::HOP_MS > MAX_UTTERANCE_MS

      Acoustic::Features.syllable_spans(analysis, count)
    end

    def grade_one(analysis, span, target, index, total)
      key = SyllableKey.for(target, store: @store)
      norm = @store.norm_for(position: index, total: total)
      template = @store.template(key, norm) || @store.template(key, TemplateStore::CITATION)

      return absent(target, key) if template.nil? || span.nil?
      return absent(target, key) if (span[1] - span[0]) * Acoustic::Features::HOP_MS < MIN_SYLLABLE_MS

      features = Acoustic::Features.extract(
        analysis,
        span,
        initial: template.dig("structure", "initial"),
        utterance_initial: index.zero?
      )
      features["f0_register"] = register(features)

      axes = analyzer.score_axes(features, template, template["norm"] || TemplateStore::CITATION)
      axes = axes.reject { |a| a["id"] == "tone" } unless @tonal

      scored = analyzer.part_scores(axes)
      weights = weights_for(key, template, norm, scored.map { |p| p["id"] })
      shares = Acoustic::Weights.shares(weights)
      overall = analyzer.weighted_overall(scored, weights)

      best = @tonal ? best_match(features, key, template) : nil
      evaluation = {"overall" => overall, "parts" => scored, "best_match" => best, "expected" => key}

      @verdict.for_syllable(evaluation, expected: key).merge(
        "char" => target["char"],
        "pinyin" => target["pinyin"],
        "zhuyin" => target["zhuyin"],
        "key" => key,
        "index" => index,
        "tone" => template["tone"],
        "parts" => present_parts(scored, shares, zhuyin_of(target, template), template["tone"]),
        "contour" => contour(scored),
        "advisories" => advisories(axes),
        "sounded_like" => confusion(key, best, scored),
        "deviations" => analyzer.deviations(features, template),
        "codes" => axes.map { |a| a["code"] }.reject { |code| code.end_with?(".ok") },
        "features" => digest(features, scored),
        "diagnostics" => diagnostics(features, axes, template)
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

    def diagnostics(features, axes, template)
      {
        "voice" => voice_digest,
        "signal" => {
          "duration_ms" => features["duration_ms"]&.round,
          "voiced_ms" => features["voiced_ms"]&.round,
          "f0_ref_hz" => features["f0_ref_hz"]&.round(1),
          "f0_folded" => octave_folded?(features),
          "vot_ms" => features["vot_ms"]&.round(1),
          "vot_reliable" => features["vot_reliable"],
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
      descriptors = Parts.describe(zhuyin) + [tone_descriptor(tone)]

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

    def tone_descriptor(tone)
      {"id" => "tone", "present" => tone.present?, "zhuyin" => TONE_MARKS[tone], "pinyin" => tone.to_s, "ipa" => nil}
    end

    def contour(scored)
      measured = scored.find { |p| p["id"] == "tone" }&.fetch("measured", nil)
      return nil if measured.blank? || measured["curve"].blank?

      measured.slice("curve", "reference", "sigma", "range", "slope", "register")
    end

    def advisories(axes)
      analyzer
        .advisories(axes)
        .reject { |a| a["code"].to_s.end_with?(".ok") }
        .filter_map { |a|
          note = @coach.advisory(a["code"])
          {"id" => a["id"], "score" => a["score"], "note" => note} if note
        }
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

    def best_match(features, key, template)
      ranking = analyzer.rank_candidates(features, key, template["norm"] || TemplateStore::CITATION)
      ranking.first&.fetch("key", nil)
    rescue StandardError
      key
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
      bytes = audio.respond_to?(:read) ? audio.read : audio.to_s
      return [nil, nil] if bytes.blank?

      Acoustic::Dsp.parse_wav(bytes)
    rescue StandardError
      [nil, nil]
    end
  end
end
