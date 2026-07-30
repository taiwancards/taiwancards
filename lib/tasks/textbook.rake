# frozen_string_literal: true

require_relative "../rake_progress"

namespace(:textbook) do
  desc("Load lessons from dumps and download audio (idempotent, one command for any deploy)")
  task(setup: :environment) do
    Rake::Task["textbook:load"].invoke
    Rake::Task["textbook:download_audio"].invoke
  end

  desc("Ingest loaded Textbook lessons into the lexeme dictionary (characters/words/phrases + component graph)")
  task(import_lexemes: :environment) do
    progress = lambda do |kind, value, total|
      if kind == :lesson
        RakeProgress.tick(value, total, "lessons")
      else
        puts("    → #{value}")
      end
    end

    RakeProgress.report(Textbook::LexemeImporter.new(progress:).call)
  end

  desc("Fill each lesson vocabulary entry's Russian meaning from ru_glosses.json (idempotent)")
  task(enrich_vocab_ru: :environment) do
    pp(Textbook::VocabRuEnricher.new.call)
  end

  desc("Load Textbook lessons into the database from data/textbook/lessons dumps (idempotent, offline)")
  task(load: :environment) do
    dumps = AppData.glob("textbook/lessons/book-*-lesson-*.json").sort
    abort("No dumps found in data/textbook/lessons") if dumps.empty?

    dumps.each do |path|
      data = JSON.parse(path.read)
      record = TextbookLesson.find_or_initialize_by(book: data["book"], lesson: data["lesson"])
      record.update!(
        title_en: data["title_en"],
        title_zh: data["title_zh"],
        title_ru: data["title_ru"],
        summary_html: data["summary_html_en"],
        summary_html_ru: data["summary_html_ru"],
        vocabulary: data["vocabulary"]
      )
    end

    puts("Loaded #{dumps.size} Textbook lessons from dumps")
  end

  desc("Regenerate lesson dumps from the raw captures (keeps existing Russian translations)")
  task(dump: :environment) do
    Textbook::RawParser.new.each_lesson do |attributes|
      path = AppData.path(
        "textbook/lessons/book-#{attributes[:book]}-lesson-#{format("%02d", attributes[:lesson])}.json"
      )
      existing = path.exist? ? JSON.parse(path.read) : {}
      ru_meanings = (existing["vocabulary"] || []).to_h { |entry| [entry["name"], entry["meaning_ru"]] }
      payload = {
        book: attributes[:book],
        lesson: attributes[:lesson],
        title_en: attributes[:title_en],
        title_zh: attributes[:title_zh],
        title_ru: existing["title_ru"],
        summary_html_en: attributes[:summary_html],
        summary_html_ru: existing["summary_html_ru"],
        vocabulary: attributes[:vocabulary].map { |entry|
          entry.merge("meaning_ru" => ru_meanings[entry["name"]])
        }
      }
      path.write(JSON.pretty_generate(payload))
    end

    puts("Dumps regenerated in data/textbook/lessons")
  end
end
