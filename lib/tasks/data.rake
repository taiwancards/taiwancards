# frozen_string_literal: true

namespace(:data) do
  desc("Copy bulk data (huayu, dictionaries) onto DATA_ROOT. Idempotent.")
  task(install: :environment) do
    abort("DATA_ROOT is not set — nothing to install into.") unless AppData.external?

    AppData::MIRRORED_DIRS.each do |dir|
      source = AppData.local_roots.map { |base| base.join(dir) }.find(&:directory?) || AppData.own_root.join(dir)
      target = AppData.target_path(dir)

      unless source.directory?
        puts("skip #{dir}: not present in this checkout")
        next
      end

      FileUtils.mkdir_p(target)
      copied = 0
      skipped = 0
      Dir.glob("#{source}/**/*", File::FNM_DOTMATCH).each do |entry|
        next if File.basename(entry).start_with?(".") && File.directory?(entry)

        relative = Pathname(entry).relative_path_from(source)
        destination = target.join(relative)

        if AppData.excluded?(File.join(dir, relative))
          skipped += 1
          next
        end

        if File.directory?(entry)
          FileUtils.mkdir_p(destination)
          next
        end

        if destination.exist? && destination.size == File.size(entry) &&
            destination.mtime >= File.mtime(entry)
          next
        end

        FileUtils.mkdir_p(destination.dirname)
        FileUtils.cp(entry, destination)
        copied += 1
      end

      note = skipped.positive? ? " (#{skipped} excluded)" : ""
      puts("#{dir}: #{copied} file(s) copied into #{target}#{note}")
    end

    puts("data:install complete")
  end

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
