# frozen_string_literal: true

class PronunciationController < ApplicationController
  include PracticeQueue

  QUEUE_SIZE = Pronunciation::Queue::SIZE
  QUEUE_SLOT = "pron_practice"

  def show
    @collection = Collection.studyable_by(current_user).find_by(id: params[:collection_id])
    @drills = Pronunciation::Drills.instance
    @section = @drills.section(params[:section])
    @tonal = params[:section].blank? || !params[:section].to_s.start_with?("initials_", "vowel_")
    @lexeme = pick_lexeme
    @audio = @lexeme && helpers.audio_for(@lexeme)
    @syllables = @lexeme ? Huayu::PronunciationTarget.new(@lexeme).syllables : []
    @health_url = pronunciation_health_path(locale: nil)
    @grade_url = pronunciation_grade_path(locale: nil)
    @advance_url = pronunciation_path(
      {collection_id: @collection&.id, section: @section&.fetch("id", nil)}.compact.merge(advance: 1)
    )
    @auto = recording_limits
    @legend = Pronunciation::Legend.new.rows
    @voice = voice_profile
    @risky = risky_syllables
    @sandhi = sandhi_syllables
    @keeping = current_user&.restricted_access?
  end

  def health
    render(json: Pronunciation::AcousticBackend.new.health)
  end

  def thresholds
    render(json: Pronunciation::TemplateStore.instance.thresholds)
  end

  def template
    norm = params[:norm].presence_in(Pronunciation::TemplateStore::NORMS) || Pronunciation::TemplateStore::CITATION
    data = Pronunciation::TemplateStore.instance.template(params[:key], norm)
    return head(:not_found) if data.nil?

    expires_in(1.day, public: true)
    render(json: data)
  end

  def grade
    result = Pronunciation::GradeAttempt
      .new(user: current_user, voice: voice_profile, tonal: params[:tonal].to_s != "false")
      .call(
        audio: recorded_bytes,
        text: params[:text],
        expected: parse_expected,
        takes: params[:takes].to_i,
        lexeme_id: params[:lexeme_id],
        schedule: params[:schedule].to_s != "false",
        content_type: params[:audio].try(:content_type)
      )

    return render(json: {status: "busy"}, status: :too_many_requests) if result == :busy
    return render(json: {status: "offline"}, status: :service_unavailable) if result.nil?
    return render(json: result, status: :unprocessable_content) if result["status"] == "retry"

    render(json: result)
  end

  private

  def recorded_bytes
    audio = params[:audio]
    audio.respond_to?(:read) ? audio.read : audio.to_s
  end

  def recording_limits
    auto = Setting.instance.pron_auto
    room = @syllables.length * Pronunciation::AcousticBackend::PER_SYLLABLE_MS
    room > auto[:max_ms] ? auto.merge(max_ms: room) : auto
  end

  def parse_expected
    parsed = JSON.parse(params[:expected].to_s)
    parsed.is_a?(Array) ? parsed.grep(Hash) : []
  rescue JSON::ParserError
    []
  end

  def pronounceable = Pronunciation::Queue.pronounceable(@collection)

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

    risky = @syllables.reject { |syllable|
      Pronunciation::SyllableKey.candidates(syllable).any? { |key| @drills.approves?(key) }
    }

    (risky.length * 2 > @syllables.length) ? [] : risky
  end

  def pick_lexeme
    return practiceable(params[:lexeme_id]) if params[:lexeme_id].present?
    return pick_from_section if @section

    queue, position = practice_queue(QUEUE_SLOT, deck: @collection&.id) { build_queue }
    practiceable(queue[position]) || pronounceable.order(Arel.sql("RANDOM()")).first
  end

  def practiceable(id)
    pronounceable.find_by(id:) || phrase(id)
  end

  def phrase(id)
    return nil if @collection || !Pronunciation::Phrases.instance.include?(id.to_i)

    Lexeme.where(kind: :sentence).find_by(id:)
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
        user: current_user,
        collection: @collection,
        drills: @drills
      )
      .ids

    ids.presence || pronounceable.curriculum_order.limit(QUEUE_SIZE).pluck(:id)
  end
end
