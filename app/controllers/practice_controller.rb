# frozen_string_literal: true

class PracticeController < ApplicationController
  allow_unauthenticated_access only: %i[zhuyin]
  PHONETICS_PARTS = %w[intro initials finals tricky].freeze

  DRILL_SIZE = 20
  MAX_TRACKED = 200

  def index
  end

  def pinyin
    redirect_to(practice_zhuyin_path, status: :moved_permanently)
  end

  def zhuyin
    @part = params[:part].to_s.presence_in(PHONETICS_PARTS) || PHONETICS_PARTS.first
    index = PHONETICS_PARTS.index(@part)
    @part_neighbors = {
      previous: (PHONETICS_PARTS[index - 1] if index.positive?),
      next: PHONETICS_PARTS[index + 1]
    }
    load_phonetics
  end

  def drill
    drill = Huayu::PhoneticsDrill.new(locale: I18n.locale)
    @stages = Huayu::PhoneticsDrill::STAGES
    @items = @stages.index_with { |stage| drill.items(stage) }
    @weak = current_user.phonetic_misses
    @size = DRILL_SIZE
  end

  def drill_result
    current_user.record_phonetic_misses!(submitted_misses)
    current_user.record_practice_run!(:drill)
    head(:no_content)
  end

  TYPING_MODES = %w[pinyin hanzi].freeze

  def typing
    @layout = Huayu::ZhuyinKeyboard.layout
    @mode = params[:mode].to_s.presence_in(TYPING_MODES) || default_typing_mode
    @words = typing_words(@mode)

    if @mode == "hanzi" && @words.size < 5
      @fell_back = true
      @mode = "pinyin"
      @words = typing_words(@mode)
    end
  end

  def typing_result
    current_user.record_practice_run!(:typing)
    head(:no_content)
  end

  def progress
    @runs = current_user.practice_runs
    @misses = current_user.phonetic_misses.sort_by { |_key, count| -count }.first(12)
    stats = Pronunciation::ToneStats.new(current_user)
    @tone_accuracy = stats.accuracy_by_tone
    @tone_confusions = stats.confusions
    @initial_accuracy = stats.accuracy_by_initial

    focus = Pronunciation::Focus.new(current_user)
    @focus = focus.weaknesses
    @focus_summary = focus.summary
  end

  private

  def default_typing_mode
    current_user.level_grade.positive? ? "hanzi" : "pinyin"
  end

  def typing_words(mode)
    scope = Lexeme
      .visible_to(current_user)
      .where(kind: %i[character word])
      .where("lexemes.readings->>'zhuyin' IS NOT NULL")

    scope = if mode == "hanzi"
      scope.where(id: studied_lexeme_ids)
    else
      scope.where("lexemes.readings->>'pinyin' IS NOT NULL")
    end

    scope
      .curriculum_order
      .limit(60)
      .map { |lexeme|
        {
          text: lexeme.text,
          prompt: mode == "hanzi" ? lexeme.text : lexeme.readings["pinyin"],
          zhuyin: lexeme.readings["zhuyin"],
          meaning: lexeme.meaning(I18n.locale)
        }
      }
  end

  def studied_lexeme_ids
    LexemeMemory
      .owned_by(current_user)
      .where
      .not(state: LexemeMemory.states[:unseen])
      .select(:lexeme_id)
  end

  def load_phonetics
    @initials = Huayu::Phonetics.initials
    @finals = Huayu::Phonetics.finals
    @rimes = Huayu::Phonetics.rimes
  end

  def submitted_misses
    raw = params[:misses]
    return {} if raw.blank?

    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    hash.first(MAX_TRACKED).to_h
  end
end
