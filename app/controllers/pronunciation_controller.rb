# frozen_string_literal: true

require "json"

class PronunciationController < ApplicationController
  QUEUE_SIZE = Pronunciation::Queue::SIZE

  def show
    @collection = Collection.where(user_id: [nil, Current.user&.id]).find_by(id: params[:collection_id])
    @drills = Pronunciation::Drills.instance
    @section = @drills.section(params[:section])
    @tonal = params[:section].blank? || !params[:section].to_s.start_with?("initials_", "vowel_")
    @lexeme = pick_lexeme
    @syllables = @lexeme ? Huayu::PronunciationTarget.new(@lexeme).syllables : []
    @speech_url = pronunciation_path
    @advance_url = pronunciation_path(
      {collection_id: @collection&.id, section: @section&.fetch("id", nil)}.compact.merge(advance: 1)
    )
    @auto = Setting.instance.pron_auto
    @legend = Pronunciation::Legend.new.rows
    @voice = voice_profile
    @risky = risky_syllables
    @sandhi = sandhi_syllables
  end

  def health
    render(json: Pronunciation::AcousticBackend.new.health)
  end

  def thresholds
    render(json: Pronunciation::TemplateStore.instance.thresholds)
  end

  def template
    data = Pronunciation::TemplateStore.instance.template(params[:key], params[:norm].presence || "taiwan")
    return head(:not_found) if data.nil?

    expires_in(1.day, public: true)
    render(json: data)
  end

  def grade
    tonal = params[:tonal].to_s != "false"
    voice = voice_profile
    result = Pronunciation::AcousticBackend
      .new(tonal:, voice:)
      .grade(audio: params[:audio], text: params[:text], syllables: parse_expected)
    return render(json: {status: "offline"}, status: :service_unavailable) if result.nil?

    lexeme = Lexeme.where(kind: %i[word character]).find_by(id: params[:lexeme_id])
    record_attempt(lexeme, result) if lexeme
    refine_voice(voice, result)
    render(json: result)
  end

  private

  def voice_profile
    return nil if Current.user.nil?

    VoiceProfile.find_by(user: Current.user)
  end

  def refine_voice(voice, result)
    return if voice.nil?

    Array(result["syllables"]).each do |syllable|
      curve = syllable.dig("contour", "curve")
      next if curve.blank? || syllable["tone"].blank?

      Pronunciation::Calibration.refine!(
        voice,
        f0_values: absolute_pitch(syllable),
        tone: syllable["tone"],
        score: syllable["overall"]
      )
    end
  end

  def absolute_pitch(syllable)
    reference = syllable.dig("features", "f0_ref_hz")
    return [] if reference.blank?

    syllable.dig("contour", "curve").map { |semitones| reference * (2 ** (semitones / 12.0)) }
  end

  def parse_expected
    JSON.parse(params[:expected].to_s)
  rescue JSON::ParserError
    []
  end

  def record_attempt(lexeme, result)
    syllables = Array(result["syllables"])
    ok = syllables.any? && syllables.all? { |s| s["level"] == "green" }

    Pronunciation::SkillRecorder.new(Current.user, lexeme).call(syllables)

    memory = Lexemes::Activator.new.activate(lexeme, :tone)
    Lexemes::ReviewProcessor.new.call(memory, rating: ok ? "good" : "again")
  end

  def pronounceable
    scope = Lexeme.where(kind: %i[word character]).where("readings ->> 'pinyin' IS NOT NULL")
    scope = scope.where(id: @collection.lexemes.select(:id)) if @collection
    scope
  end

  def sandhi_syllables
    @syllables
      .select { |syllable|
        syllable["base_tone"].present? && syllable["tone"].to_i != syllable["base_tone"].to_i
      }
      .map { |syllable|
        base = syllable["zhuyin"].to_s.delete(Pronunciation::Parts::TONE_CHARS)
        syllable.merge("surface_zhuyin" => Huayu::Zhuyin.apply_tone(base, syllable["tone"].to_i))
      }
  end

  def risky_syllables
    return [] unless @drills.available?

    @syllables.reject { |syllable|
      Pronunciation::SyllableKey.candidates(syllable).any? { |key| @drills.approves?(key) }
    }
  end

  def pick_lexeme
    return pronounceable.find_by(id: params[:lexeme_id]) if params[:lexeme_id].present?
    return pick_from_section if @section

    queue = Array(session[queue_key])
    position = session[position_key].to_i
    position += 1 if params[:advance].present?

    if queue.empty? || position >= queue.size
      queue = build_queue
      position = 0
    end

    session[queue_key] = queue
    session[position_key] = position
    pronounceable.find_by(id: queue[position]) || pronounceable.order(Arel.sql("RANDOM()")).first
  end

  def pick_from_section
    keys = Pronunciation::Drills.instance.keys_for(@section["id"])
    return nil if keys.empty?

    position = session[section_key].to_i
    position += 1 if params[:advance].present?
    position = 0 if position >= keys.length
    session[section_key] = position

    @drill_key = keys[position]
    Lexeme.where(kind: %i[word character]).find_by(id: lexeme_id_for_key(@drill_key))
  end

  def lexeme_id_for_key(key)
    Pronunciation::SyllableIndex.lookup(key)
  end

  def section_key = "pron_section_#{@section["id"]}"

  def build_queue
    ids = Pronunciation::Queue
      .new(
        user: Current.user,
        collection: @collection,
        drills: @drills
      )
      .ids

    ids.presence || pronounceable.curriculum_order.limit(QUEUE_SIZE).pluck(:id)
  end

  def queue_key
    @collection ? "pron_queue_#{@collection.id}" : "pron_queue"
  end

  def position_key
    @collection ? "pron_position_#{@collection.id}" : "pron_position"
  end
end
