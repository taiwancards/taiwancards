# frozen_string_literal: true

module Textbook
  class LexemeImporter
    HAN = /\p{Han}/

    def initialize(progress: nil)
      @progress = progress || -> (*) { }
      @upserter = Lexemes::Upserter.new
      @characters = {}
    end

    def call
      @sentence_texts = []
      lessons = TextbookLesson.ordered.to_a
      lessons.each_with_index do |lesson, index|
        import_lesson(lesson)
        @progress.call(:lesson, index + 1, lessons.size)
      end

      %i[cleanup_stale_sentences link_phrases_to_words aggregate_character_readings].each do |phase|
        @progress.call(:phase, phase, nil)
        send(phase)
      end

      stats
    end

    private

    def import_lesson(lesson)
      collection = collection_for(lesson)
      position = 0
      lesson.vocabulary.each do |entry|
        lexeme = import_entry(lesson, entry)
        next if lexeme.nil?

        collection.add_lexeme(lexeme, position:)
        position += 1
      end

      collection.update!(items_count: collection.collection_items.count)
      import_sentences(lesson)
    end

    def import_sentences(lesson)
      source = "Textbook #{lesson.label}"
      Textbook::SentenceExtractor.new.call(lesson).each do |sentence|
        text = sentence["traditional"]
        meanings = {"en" => sentence["meaning_en"], "ru" => sentence["meaning_ru"]}.compact_blank
        is_sentence = sentence["sentence"]
        data = is_sentence ? {"sentence" => true} : {}
        lexeme = @upserter.phrase(text, meanings:, source:, data:)
        demote_to_collocation(lexeme) unless is_sentence
        @upserter.link(lexeme, characters_of(text, source))
        @sentence_texts << text if is_sentence
      end
    end

    def demote_to_collocation(lexeme)
      return unless lexeme.data["sentence"]

      lexeme.update!(data: lexeme.data.except("sentence"))
    end

    def cleanup_stale_sentences
      valid = @sentence_texts.to_set
      Lexeme
        .where(kind: :phrase)
        .where("data ->> 'sentence' = 'true'")
        .find_each do |phrase|
          next if valid.include?(phrase.text)

          phrase.update!(data: phrase.data.except("sentence"))
        end
    end

    def import_entry(lesson, entry)
      text = entry["traditional"].to_s
      return if text.blank?

      meanings = {"en" => entry["meaning"], "ru" => entry["meaning_ru"]}.compact_blank
      source = "Textbook #{lesson.label}"
      audio = lesson.audio_url(entry)

      if entry["category"] == "Ph"
        lexeme = @upserter.phrase(text, meanings:, audio_url: audio, source:)
        @upserter.link(lexeme, characters_of(text, source))
      else
        lexeme = @upserter.word(
          text,
          readings: {"pinyin" => entry["pinyin"], "zhuyin" => Huayu::Zhuyin.from_pinyin(entry["pinyin"])},
          meanings:,
          audio_url: audio,
          pos: entry["category"],
          source:
        )
        han = text.chars.select { |char| char.match?(HAN) }
        @upserter.link(lexeme, characters_of(text, source), readings: character_readings(han, entry["pinyin"]))
      end

      lexeme
    end

    def characters_of(text, source)
      text.chars.select { |char| char.match?(HAN) }.map do |char|
        @characters[char] ||= @upserter.character(char, source:)
      end
    end

    def character_readings(han_chars, pinyin)
      syllables = Huayu::Zhuyin.syllabify(pinyin)
      return [] if syllables.nil? || syllables.length != han_chars.length

      syllables.map { |syllable| syllable["pinyin"] }
    end

    def aggregate_character_readings
      Lexeme.where(kind: :character).find_each do |character|
        readings = character.parent_links.where.not(reading: [nil, ""]).group(:reading).count
        next if readings.empty?

        ordered = readings.sort_by { |reading, count| [-count, reading] }.map(&:first)
        character.readings = {"pinyin" => ordered.first, "zhuyin" => Huayu::Zhuyin.from_pinyin(ordered.first)}
        character.data = character.data.merge(
          "readings" => ordered.map { |pinyin| {"pinyin" => pinyin, "zhuyin" => Huayu::Zhuyin.from_pinyin(pinyin)} }
        )
        character.save!
      end
    end

    def link_phrases_to_words
      words = Lexeme.where(kind: :word)
      segmenter = Huayu::Segmenter.new(words.pluck(:text))
      word_by_text = words.index_by(&:text)

      Lexeme.where(kind: :phrase).find_each do |phrase|
        components = segmenter.segment(phrase.text).filter_map { |token| word_by_text[token] }
        @upserter.link(phrase, components)
      end
    end

    def collection_for(lesson)
      Collection
        .create_with(
          kind: :lesson,
          description: lesson.title_zh,
          level_tag: "Textbook B#{lesson.book}",
          position: (lesson.book * 100) + lesson.lesson
        )
        .find_or_create_by!(name: "Textbook #{lesson.label} · #{lesson.title_en}")
    end

    def stats
      {
        characters: Lexeme.where(kind: :character).count,
        words: Lexeme.where(kind: :word).count,
        phrases: Lexeme.where(kind: :phrase).count,
        links: LexemeLink.count,
        collections: Collection.count
      }
    end
  end
end
