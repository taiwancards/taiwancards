# frozen_string_literal: true

module Offline
  class Pages
    include Rails.application.routes.url_helpers

    Result = Data.define(:paths, :entries)

    Entry = Data.define(:text, :zhuyin, :pinyin, :en, :ru, :path, :kind) do
      def to_row = [text, zhuyin, pinyin, en, ru, path, kind]
    end

    CORE_PATHS = %w[
      /offline
      /offline/browse
      /hanzi
      /syllables
      /variants
      /metro
      /names
      /tones
      /cangjie
    ].freeze

    TAIWAN_PATHS = %w[/everyday /phrases /notices /calendar /medicine /games /metro].freeze

    SENTENCE_LIMIT = 8_000

    def initialize(section)
      @section = section
    end

    def call
      return level if section.levelled?

      case section.id
      when "core"
        core
      when "grammar"
        grammar
      when "graded"
        graded
      when "cangjie"
        cangjie
      when "taiwan"
        taiwan
      when "reference"
        reference
      when "chengyu"
        chengyu
      else
        Result.new(paths: [], entries: [])
      end
    end

    private

    attr_reader :section

    def core = Result.new(paths: CORE_PATHS, entries: [])

    def grammar
      lessons = Huayu::GrammarLessons.all
      Result.new(
        paths: [grammar_path, *lessons.map { |lesson| grammar_lesson_path(id: lesson.to_param) }],
        entries: lessons.map { |lesson| lesson_entry(lesson) }
      )
    end

    def lesson_entry(lesson)
      Entry.new(
        text: lesson.head.to_s,
        zhuyin: "",
        pinyin: "",
        en: lesson.title(:en).to_s,
        ru: lesson.title(:ru).to_s,
        path: grammar_lesson_path(id: lesson.to_param),
        kind: "grammar"
      )
    end

    def graded
      texts = Graded::Library.all
      tiers = Graded::Library.tiers
      Result.new(
        paths: [
          graded_path,
          *tiers.map { |tier| graded_tier_path(tier: tier) },
          *texts.map { |text| graded_text_path(tier: text.tier, id: text.id) }
        ],
        entries: texts.map { |text| graded_entry(text) }
      )
    end

    def graded_entry(text)
      Entry.new(
        text: text.zh.to_s,
        zhuyin: "",
        pinyin: "",
        en: text.title(:en).to_s,
        ru: text.title(:ru).to_s,
        path: graded_text_path(tier: text.tier, id: text.id),
        kind: "text"
      )
    end

    def cangjie
      lessons = Huayu::CangjieLessons.all
      Result.new(
        paths: [cangjie_path, cangjie_lessons_path, *lessons.map { |lesson| cangjie_lesson_path(id: lesson.to_param) }],
        entries: lessons.map { |lesson| cangjie_entry(lesson) }
      )
    end

    def cangjie_entry(lesson)
      Entry.new(
        text: lesson.letter.to_s,
        zhuyin: "",
        pinyin: lesson.key.to_s,
        en: lesson.title_for(:en).to_s,
        ru: lesson.title_for(:ru).to_s,
        path: cangjie_lesson_path(id: lesson.to_param),
        kind: "text"
      )
    end

    def taiwan = Result.new(paths: TAIWAN_PATHS, entries: [])

    def reference
      lexemes = Lexeme.where(kind: %i[radical measure_word particle]).to_a
      Result.new(
        paths: [
          radicals_path,
          liangci_path,
          zhuci_path,
          tocfl_levels_path,
          tbcl_levels_path,
          *lexemes.map { |lexeme| lexeme_path_for(lexeme) }
        ],
        entries: lexemes.map { |lexeme| lexeme_entry(lexeme) }
      )
    end

    def chengyu
      lexemes = Lexeme
        .where(kind: Lexeme::DICTIONARY_KINDS)
        .visible_to(nil)
        .where("lexemes.data ->> 'chengyu' = 'true'")
        .to_a

      Result.new(
        paths: lexemes.map { |lexeme| lexeme_path_for(lexeme) },
        entries: lexemes.map { |lexeme| lexeme_entry(lexeme) }
      )
    end

    def level
      words = level_words
      characters = level_characters(words)
      sentences = level_sentences
      lexemes = words + characters

      Result.new(
        paths: [
          *lexemes.map { |lexeme| lexeme_path_for(lexeme) },
          *sentences.map { |row| sentence_path(id: row.to_param) }
        ],
        entries: [*lexemes.map { |lexeme| lexeme_entry(lexeme) }, *sentences.map { |row| sentence_entry(row) }]
      )
    end

    def level_words
      collection = Collection.find_by(kind: :tocfl, level_tag: section.level)
      return [] if collection.nil?

      Lexeme.visible_to(nil).where(id: collection.collection_items.select(:lexeme_id)).to_a
    end

    def level_characters(words)
      return [] if words.empty?

      ids = LexemeLink.where(parent_id: words.map(&:id)).distinct.pluck(:child_id)
      Lexeme.visible_to(nil).where(kind: %i[character radical], id: ids).to_a
    end

    def level_sentences
      position = SentenceProfile::TOCFL_LEVELS.index(section.level)
      return [] if position.nil?

      Lexeme
        .visible_to(nil)
        .where(kind: :sentence)
        .where(id: SentenceProfile.where(tocfl_exact: true, tocfl_index: position + 1).select(:lexeme_id))
        .order(:score, :id)
        .limit(SENTENCE_LIMIT)
        .to_a
    end

    def lexeme_path_for(lexeme)
      case lexeme.kind.to_s
      when "character"
        character_path(text: lexeme.text)
      when "radical"
        radical_path(text: lexeme.text)
      when "sentence"
        sentence_path(id: lexeme.to_param)
      when "measure_word"
        liangci_entry_path(text: lexeme.text)
      when "particle"
        zhuci_entry_path(text: lexeme.text)
      else
        dict_entry_path(text: lexeme.text)
      end
    end

    def lexeme_entry(lexeme)
      reading = lexeme.readings.is_a?(Hash) ? lexeme.readings : {}

      Entry.new(
        text: lexeme.text,
        zhuyin: reading["zhuyin"].to_s,
        pinyin: reading["pinyin"].to_s,
        en: lexeme.meanings["en"].to_s,
        ru: lexeme.meanings["ru"].to_s,
        path: lexeme_path_for(lexeme),
        kind: lexeme.kind.to_s
      )
    end

    def sentence_entry(lexeme)
      Entry.new(
        text: lexeme.text,
        zhuyin: "",
        pinyin: "",
        en: lexeme.meanings["en"].to_s,
        ru: lexeme.meanings["ru"].to_s,
        path: sentence_path(id: lexeme.to_param),
        kind: "sentence"
      )
    end
  end
end
