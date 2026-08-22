# frozen_string_literal: true

module Huayu
  class SourceAudit
    Entry = Data.define(:label, :path, :required, :group)

    DATA = %w[
      content_sources.json
      huayu/chengyu.json
      huayu/classifier_pairs.json
      huayu/collocation_glosses.jsonl
      huayu/common_words.json
      huayu/corpus_frequency.json
      huayu/games.json
      huayu/gloss_overrides.json
      huayu/kangxi_radicals.json
      huayu/china_markers.json
      huayu/measure_words.json
      huayu/moe4808.json
      huayu/moe_idioms.json
      huayu/moe_next6343.json
      huayu/parts_of_speech.json
      huayu/ru_glosses.json
      huayu/school_levels.json
      huayu/sense_glosses.jsonl
      huayu/sentence_glosses.jsonl
      huayu/taiwan_everyday.json
      huayu/thesaurus.json
      huayu/tocfl.csv
      huayu/tocfl_official.json
      corpora/sentences
    ]
      .freeze

    DATA_OPTIONAL = %w[
      huayu/bigram_frequency.json
      huayu/segmentation_vocab.json
      huayu/song_vocabulary.json
      huayu/cangjie_index.json
      huayu/cangjie_lessons.json
      huayu/hanzi_structure.json
      huayu/holidays.json
      huayu/lunar_years.json
      huayu/phonetics.json
      huayu/solar_terms.json
      huayu/tea_classes.json
      textbook/lessons
      pronunciation
    ]
      .freeze

    CORPORA = %w[
      dictionaries/cangjie5.tsv
      dictionaries/cedict.json
      dictionaries/makemeahanzi/dictionary.txt
      dictionaries/makemeahanzi/graphics.txt
      dictionaries/simp_to_trad.txt
    ]
      .freeze

    CORPORA_OPTIONAL = %w[
      corpora/dict.json
      corpora/concised.json
      corpora/moedict/dict-revised.json
      corpora/moe_examples.json
      corpora/etymology.json
      dictionaries/sources/moe/hanzi_table_202209.xlsx
      dictionaries/sources/moe/word_table_14452_202504.xlsx
    ]
      .freeze

    MEDIA_OPTIONAL = %w[
      moe_audio
      moe_audio_words
      pronunciation
      audio
    ].freeze

    def entries
      list = []
      DATA.each { |name|
        list << Entry.new(label: "data/#{name}", path: AppData.path(name), required: true, group: "data")
      }
      DATA_OPTIONAL.each { |name|
        list << Entry.new(label: "data/#{name}", path: AppData.path(name), required: false, group: "data")
      }
      CORPORA.each { |name|
        list << Entry.new(label: "dict_and_corpora/#{name}", path: corpora(name), required: true, group: "corpora")
      }
      CORPORA_OPTIONAL.each { |name|
        list << Entry.new(label: "dict_and_corpora/#{name}", path: corpora(name), required: false, group: "corpora")
      }
      MEDIA_OPTIONAL.each { |name|
        list << Entry.new(label: "media/#{name}", path: media(name), required: false, group: "media")
      }
      list
    end

    def call
      entries.select(&:required).reject { |entry| present?(entry.path) }.map(&:label)
    end

    def optional_missing
      entries.reject(&:required).reject { |entry| present?(entry.path) }.map(&:label)
    end

    def report
      entries.map do |entry|
        {
          label: entry.label,
          group: entry.group,
          required: entry.required,
          present: present?(entry.path),
          size: size_of(entry.path)
        }
      end
    end

    private

    def corpora(name)
      Pathname(ENV.fetch("CORPORA_DIR") { Rails.root.join("dict_and_corpora").to_s }).join(name)
    end

    def media(name)
      AppData.media_root.join(name)
    end

    def present?(path)
      return false unless File.exist?(path)
      return Dir.children(path).any? if File.directory?(path)

      File.size(path).positive?
    end

    def size_of(path)
      return nil unless File.exist?(path)
      return "directory, #{Dir.children(path).size}" if File.directory?(path)

      bytes = File.size(path)
      return "#{(bytes / 1024.0 / 1024).round(1)} MB" if bytes > 1024 * 1024

      "#{(bytes / 1024.0).round} KB"
    end
  end
end
