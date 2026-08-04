# frozen_string_literal: true

namespace(:data) do
  desc("Report what bulk data is present, where it is read from, and how much space it uses")
  task(doctor: :environment) do
    puts("DATA_ROOT   : #{ENV["DATA_ROOT"].presence || "(unset — reading from the repo)"}")
    puts("Reading from: #{AppData.root}")
    puts("")

    total = 0
    AppData::MIRRORED_DIRS.each do |dir|
      path = AppData.path(dir)
      unless path.directory?
        puts(format("%-28s MISSING", dir))
        next
      end

      files = Dir.glob("#{path}/**/*").count { |entry| File.file?(entry) }
      bytes = Dir.glob("#{path}/**/*").sum { |entry| File.file?(entry) ? File.size(entry) : 0 }
      total += bytes
      puts(format("%-28s %6d files  %8.1f MB", dir, files, bytes / 1024.0 / 1024.0))
    end

    puts("")
    puts(format("total on DATA_ROOT: %.1f MB", total / 1024.0 / 1024.0))

    audio = AppData.media_path(TextbookLesson::AUDIO_DIR)
    clips = audio.directory? ? audio.glob("*.mp3").length : 0
    puts("restricted audio: #{clips} clip(s) under #{audio}")

    %w[
      huayu/moe4808.json
      huayu/sense_glosses.jsonl
      dictionaries/makemeahanzi/graphics.txt
    ].each do |probe|
      puts(format("%-46s %s", probe, AppData.path(probe).exist? ? "ok" : "MISSING"))
    end
  end
end
