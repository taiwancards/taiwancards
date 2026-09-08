# frozen_string_literal: true

module Deploy
  module SyncSteps
    Step = Data.define(:name, :task, :paths, :media_paths, :code) do
      def initialize(name:, task:, paths: [], media_paths: [], code: [])
        super
      end

      def sources = paths.map { |relative| AppData.path(relative) } +
        media_paths.map { |relative| AppData.media_path(relative) }

      def code_paths = code.map { |relative| Rails.root.join(relative) }
    end

    DICTIONARY_SOURCES = %w[
      huayu/common_words.json
      huayu/taiwan_places.json
      huayu/naer_terms.json
      huayu/taiwan_everyday.json
      huayu/medicine.json
      huayu/games.json
      huayu/song_vocabulary.json
      huayu/no_segment.json
    ]
      .freeze

    CURATED_PAGE_SOURCES = %w[
      huayu/taiwan_everyday.json
      huayu/medicine.json
      huayu/games.json
      huayu/taiwan_places.json
    ]
      .freeze

    SEGMENTATION_SOURCES = (%w[
      huayu/bigram_frequency.json
      huayu/segmentation_vocab.json
      huayu/segmentation_names.json
      huayu/segmentation_priors.json
    ] +
      DICTIONARY_SOURCES)
      .freeze

    STEPS = [
      Step.new(
        name: "textbook",
        task: "textbook:load",
        paths: %w[textbook],
        code: %w[app/services/textbook/lexeme_importer.rb app/services/textbook/spellings.rb]
      ),
      Step.new(
        name: "textbook_lexemes",
        task: "textbook:import_lexemes",
        paths: %w[textbook],
        code: %w[
          app/services/textbook/lexeme_importer.rb
          app/services/textbook/sentence_extractor.rb
          app/services/textbook/spellings.rb
        ]
      ),
      Step.new(
        name: "content_sources",
        task: "huayu:import_sources",
        paths: %w[content_sources.json],
        code: %w[app/models/content_source.rb]
      ),
      Step.new(
        name: "taiwan_everyday",
        task: "huayu:import_everyday",
        paths: %w[huayu/taiwan_everyday.json],
        code: %w[
          app/services/huayu/taiwan_everyday_importer.rb
          app/services/huayu/curated_page_importer.rb
          app/services/lexemes/upserter.rb
        ]
      ),
      Step.new(
        name: "medicine",
        task: "huayu:import_medicine",
        paths: %w[huayu/medicine.json],
        code: %w[
          app/services/huayu/medicine_importer.rb
          app/services/huayu/curated_page_importer.rb
          app/services/lexemes/upserter.rb
        ]
      ),
      Step.new(
        name: "games",
        task: "huayu:import_games",
        paths: %w[huayu/games.json],
        code: %w[
          app/services/huayu/games_importer.rb
          app/services/huayu/curated_page_importer.rb
          app/services/lexemes/upserter.rb
        ]
      ),
      Step.new(
        name: "particles",
        task: "huayu:import_particles",
        paths: %w[huayu/particles.json],
        code: %w[app/services/huayu/particle_importer.rb]
      ),
      Step.new(
        name: "naer_terms",
        task: "huayu:import_naer",
        paths: %w[huayu/naer_terms.json],
        code: %w[app/services/huayu/naer_term_importer.rb]
      ),
      Step.new(
        name: "grammar",
        task: "huayu:import_grammar",
        paths: %w[huayu/grammar_lessons.json],
        code: %w[app/services/huayu/grammar_importer.rb app/services/huayu/grammar_lessons.rb]
      ),
      Step.new(
        name: "stories",
        task: "huayu:import_stories",
        paths: %w[huayu/reading_stories.json],
        code: %w[app/services/huayu/reading_stories.rb app/models/reading_text.rb]
      ),
      Step.new(
        name: "voiced_sentences",
        task: "huayu:mark_voiced",
        media_paths: %w[listening/manifest.json],
        code: %w[app/services/huayu/voiced_sentences.rb app/services/huayu/listening_clips.rb]
      ),
      Step.new(
        name: "common_words",
        task: "huayu:import_common_words",
        paths: %w[huayu/common_words.json],
        code: %w[app/services/huayu/common_words_importer.rb app/services/lexemes/bulk_upserter.rb]
      ),
      Step.new(
        name: "places",
        task: "huayu:import_places",
        paths: %w[huayu/taiwan_places.json],
        code: %w[app/services/huayu/place_importer.rb]
      ),
      Step.new(
        name: "no_segment",
        task: "huayu:block_segmentation",
        paths: %w[huayu/no_segment.json],
        code: %w[app/services/huayu/segmentation_blocks.rb]
      ),
      Step.new(
        name: "song_vocabulary",
        task: "huayu:import_song_vocabulary",
        paths: %w[huayu/song_vocabulary.json],
        code: %w[app/services/huayu/song_vocabulary_importer.rb app/services/lexemes/upserter.rb]
      ),
      Step.new(
        name: "school_levels",
        task: "huayu:import_tbcl",
        paths: %w[huayu/school_levels.json],
        code: %w[app/services/huayu/school_level_importer.rb]
      ),
      Step.new(
        name: "tocfl",
        task: "huayu:import_tocfl",
        paths: %w[huayu/tocfl.csv],
        code: %w[app/services/huayu/tocfl_importer.rb]
      ),
      Step.new(
        name: "difficulty",
        task: "huayu:compute_difficulty",
        paths: DICTIONARY_SOURCES + %w[huayu/moe_idioms.json],
        code: %w[app/services/lexemes/difficulty.rb]
      ),
      Step.new(
        name: "radicals",
        task: "huayu:import_radicals",
        paths: %w[huayu/kangxi_radicals.json],
        code: %w[app/services/huayu/radical_importer.rb]
      ),
      Step.new(
        name: "ru_glosses",
        task: "huayu:enrich_ru",
        paths: %w[huayu/ru_glosses.json] + CURATED_PAGE_SOURCES,
        code: %w[app/services/huayu/ru_enricher.rb app/services/huayu/curated_glosses.rb]
      ),
      Step.new(
        name: "gloss_overrides",
        task: "huayu:enrich_gloss_overrides",
        paths: %w[huayu/gloss_overrides.json] + CURATED_PAGE_SOURCES,
        code: %w[app/services/huayu/gloss_override_enricher.rb]
      ),
      Step.new(
        name: "etymology_translations",
        task: "huayu:translate_etymologies",
        paths: %w[huayu/etymology_ru.json],
        code: %w[app/services/huayu/etymology_translations.rb]
      ),
      Step.new(
        name: "phrase_drills",
        task: "huayu:import_phrase_drills",
        paths: %w[huayu/phrase_drills.txt huayu/bigram_frequency.json],
        code: %w[
          app/services/huayu/phrase_drills_importer.rb
          app/services/huayu/phrase_levels.rb
          app/services/textbook/lexeme_importer.rb
        ]
      ),
      Step.new(
        name: "sense_meanings",
        task: "huayu:fill_sense_meanings",
        paths: %w[huayu/sense_glosses.jsonl],
        code: %w[app/services/huayu/sense_meaning_filler.rb]
      ),
      Step.new(
        name: "collocation_meanings",
        task: "huayu:fill_collocation_meanings",
        paths: %w[huayu/collocation_glosses.jsonl] + CURATED_PAGE_SOURCES,
        code: %w[app/services/huayu/collocation_meaning_filler.rb app/services/huayu/curated_glosses.rb]
      ),
      Step.new(
        name: "sentence_meanings",
        task: "huayu:fill_sentence_meanings",
        paths: %w[huayu/sentence_glosses.jsonl huayu/ru_glosses.json],
        code: %w[app/services/huayu/sentence_meaning_filler.rb app/services/huayu/ru_enricher.rb]
      ),
      Step.new(
        name: "example_links",
        task: "huayu:link_examples",
        paths: %w[huayu/sentence_glosses.jsonl huayu/sense_glosses.jsonl],
        code: %w[app/services/huayu/example_linker.rb]
      ),
      Step.new(
        name: "chengyu",
        task: "huayu:import_chengyu",
        paths: %w[huayu/moe_idioms.json huayu/chengyu.json],
        code: %w[app/services/huayu/chengyu_importer.rb]
      ),
      Step.new(
        name: "parts_of_speech",
        task: "huayu:import_pos",
        paths: %w[huayu/parts_of_speech.json],
        code: %w[app/services/huayu/pos_importer.rb]
      ),
      Step.new(
        name: "thesaurus",
        task: "huayu:import_thesaurus",
        paths: %w[huayu/thesaurus.json],
        code: %w[app/services/huayu/thesaurus_importer.rb]
      ),
      Step.new(
        name: "liangci",
        task: "huayu:import_liangci",
        paths: %w[huayu/measure_words.json huayu/classifier_pairs.json],
        code: %w[app/services/huayu/liangci_importer.rb]
      ),
      Step.new(
        name: "segmentation",
        task: "huayu:resegment",
        paths: SEGMENTATION_SOURCES,
        code: %w[
          app/services/huayu/text_analyzer.rb
          app/services/huayu/bigram_frequency.rb
          app/services/huayu/segmentation_vocabulary.rb
        ]
      ),
      Step.new(
        name: "register_mix",
        task: "huayu:register_mix",
        paths: SEGMENTATION_SOURCES + %w[content_sources.json],
        code: %w[app/services/lexemes/register_mix.rb app/services/huayu/text_analyzer.rb]
      ),
      Step.new(
        name: "derived_levels",
        task: "huayu:derive_levels",
        paths: SEGMENTATION_SOURCES + %w[huayu/tocfl.csv],
        code: %w[
          app/services/lexemes/derived_levels.rb
          app/services/lexemes/level_scale.rb
          app/services/huayu/text_analyzer.rb
        ]
      )
    ].freeze

    ALWAYS = {
      "google_scopes" => -> {
        pending = User.where(google_scopes: nil).where.not(google_refresh_token: nil)
        next :skipped if pending.none?

        pending.find_each do |user|
          Google::DriveClient.new(user).sync_scopes!
        rescue => e
          warn("google_scopes could not read scopes for user #{user.id}: #{e.class}: #{e.message}")
        end

        :ran
      },
      "kind_merge" => -> {
        merge = Lexemes::KindMerge.new
        next :skipped unless merge.drift?

        merge.call
        :ran
      },
      "reading_links" => -> {
        linker = Huayu::ReadingLinker.new
        next :skipped unless linker.drift?

        linker.call
        :ran
      },
      "reading_order" => -> {
        order = Lexemes::ReadingOrder.new
        next :skipped unless order.drift?

        $stdout.puts(order.call.to_s)
        :ran
      },
      "sense_order" => -> {
        order = Lexemes::SenseOrder.new
        next :skipped unless order.drift?

        order.call
        :ran
      },
      "gloss_text" => -> {
        repair = Huayu::GlossRepair.new
        next :skipped unless repair.drift?

        $stdout.puts(repair.call.to_s)
        :ran
      },
      "etymology_text" => -> {
        repair = Huayu::EtymologyRepair.new
        next :skipped unless repair.drift?

        $stdout.puts(repair.call.to_s)
        :ran
      },
      "cangjie_codes" => -> {
        repair = Huayu::CangjieRepair.new
        next :skipped unless repair.drift?

        $stdout.puts(repair.call.to_s)
        :ran
      },
      "notices" => -> {
        importer = Huayu::NoticeImporter.new
        next :skipped unless importer.drift?

        $stdout.puts(importer.call.to_s)
        :ran
      },
      "sentence_brackets" => -> {
        repair = Huayu::SentenceBracketRepair.new
        next :skipped unless repair.drift?

        $stdout.puts(repair.call.to_s)
        :ran
      },
      "sentence_profiles" => -> {
        scope = Huayu::SentenceProfiler.vocabulary_drift? ? nil : Huayu::SentenceProfiler.stale
        next :skipped if scope && !scope.exists?

        Huayu::SentenceProfiler.new(scope: scope).call
        Huayu::SentenceProfiler.remember_vocabulary!
        :ran
      },
      "characters" => -> {
        supplementer = Huayu::CharacterSupplementer.new
        next :skipped unless supplementer.drift?

        supplementer.call
        Huayu::CharacterEnricher.new.call
        Huayu::GlossOverrideEnricher.new.call
        :ran
      },
      "character_glosses" => -> {
        repair = Huayu::CharacterGlossRepair.new
        next :skipped unless repair.drift?

        $stdout.puts(repair.call.to_s)
        :ran
      },
      "hokkien_search" => -> {
        index = Lexemes::HokkienIndex.new
        next :skipped unless index.drift?

        $stdout.puts(index.call.to_s)
        :ran
      },
      "admin_rights" => -> {
        result = Accounts::Owner.new.call
        next :skipped unless result.changed?

        $stdout.puts(result.to_s)
        :ran
      },
      "flag_restricted" => -> {
        flagger = Huayu::RestrictedFlagger.new
        next :skipped unless flagger.drift?

        flagger.call
        :ran
      },
      "sentence_case" => -> {
        caser = Lexemes::SentenceCase.new
        next :skipped unless caser.drift?

        caser.call
        :ran
      },
      "landing_counts" => -> {
        Site::Counts.warm!
        :ran
      },
      "syllable_index" => -> {
        Rails.cache.delete("pron:syllable_index")
        Pronunciation::SyllableIndex.for
        :ran
      },
      "prune_activity" => -> {
        ActivityEvent.prune_all.zero? ? :skipped : :ran
      }
    }.freeze

    WARMING = %w[landing_counts syllable_index prune_activity google_scopes].freeze
    ACCOUNT = (WARMING + %w[admin_rights]).freeze

    FILLERS = %w[
      Huayu::GlossOverrideEnricher
      Huayu::SenseMeaningFiller
      Huayu::CollocationMeaningFiller
      Huayu::ChengyuImporter
      Huayu::PosImporter
      Huayu::LiangciImporter
      Huayu::ThesaurusImporter
      Lexemes::RegisterMix
    ]
      .freeze
  end
end
