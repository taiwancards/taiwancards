# frozen_string_literal: true

namespace(:moe) do
  namespace(:audio) do
    VERSION = "20260626"
    DICT_ZIP = "dict_concised_2014_#{VERSION}.zip"
    NOTICE = "conciseddict_10312.pdf"
    BITRATE = "32k"
    SILENCE_DB = 35
    SILENCE_MIN = 0.12
    HEAD_PAD_MS = 120
    TAIL_PAD_MS = 400
    TAIL_SHARE = 0.6
    LEAD_SILENCE = 0.05
    MIN_HEAD = 0.15
    REPORT_EVERY = 250

    SCOPES = {
      "chars" => {
        id_length: 4,
        dir: "word_wav",
        parts: ["dict_concised_music_word_2014_#{VERSION}.zip"],
        stage: "moe-stage"
      },
      "words" => {
        id_length: nil,
        dir: "www_wav",
        parts: (1..5).map { |n| format("dict_concised_music_www_2014_#{VERSION}.zip.%03d", n) },
        stage: "moe-stage-words"
      }
    }.freeze

    def base = Sources.url("MOE_AUDIO_BASE_URL")

    def work_dir = Pathname(ENV.fetch("MOE_WORK", "tmp/moe"))

    def moe_workers = [Etc.nprocessors - 2, 1].max

    def human(bytes) = "#{(bytes / 1024.0 / 1024).round(1)} MB"

    def step(text) = puts("\n▸ #{text}")

    def fetch(name, into)
      target = into.join(name)
      if target.exist?
        puts("  #{name} already here (#{human(target.size)})")
        return target
      end

      into.mkpath
      puts("  downloading #{name}")
      system("curl", "-L", "--fail", "--progress-bar", "-o", target.to_s, "#{base}/download/#{name}", exception: true)
      target
    end

    def fetch_notice
      target = work_dir.join(NOTICE)
      return if target.exist?

      work_dir.mkpath
      system("curl", "-sL", "--fail", "-o", target.to_s, "#{base}/#{NOTICE}", exception: true)
    end

    def join_parts(parts, target)
      if target.exist?
        puts("  joined archive already here (#{human(target.size)})")
        return target
      end

      puts("  joining #{parts.size} parts")
      File.open(target, "wb") do |out|
        parts.each_with_index do |part, index|
          puts("    part #{index + 1}/#{parts.size} (#{human(part.size)})")
          File.open(part, "rb") { |io| IO.copy_stream(io, out) }
        end
      end

      puts("  joined into #{human(target.size)}")
      target
    end

    def head_ms(wav)
      out = `ffmpeg -hide_banner -i #{Shellwords.escape(wav.to_s)} -af silencedetect=n=-#{SILENCE_DB}dB:d=#{SILENCE_MIN} -f null - 2>&1`
      starts = out.scan(/silence_start: ([\d.]+)/).flatten.map(&:to_f)
      ends = out.scan(/silence_end: ([\d.]+)/).flatten.map(&:to_f)
      return nil if starts.empty?

      speech_at = starts.first < LEAD_SILENCE ? ends.first.to_f : 0.0
      cut = starts.find { |value| value > speech_at + MIN_HEAD }
      return nil if cut.nil?

      resume = ends.find { |value| value > cut }
      pause_ms = resume ? ((resume - cut) * 1000).round : TAIL_PAD_MS
      pad = [HEAD_PAD_MS, [TAIL_PAD_MS, (pause_ms * TAIL_SHARE).round].min].max

      ((cut * 1000) + pad).round
    end

    def dictionary_rows(scope, wanted)
      xlsx = work_dir.join("dict").glob("*.xlsx").first
      abort("dictionary spreadsheet missing") if xlsx.nil?

      sheet = Roo::Excelx.new(xlsx.to_s)
      sheet.default_sheet = sheet.sheets.first
      total = sheet.last_row
      rows = []

      (2..total).each do |number|
        puts("  scanned #{number}/#{total} rows") if (number % 10_000).zero?
        row = sheet.row(number)
        text = row[0].to_s.strip
        id = row[1].to_s.strip
        next if text.empty? || id.empty?
        next if scope[:id_length] ? id.length != scope[:id_length] : id.length <= 4
        next unless wanted.include?(text)

        rows << {text:, id:, zhuyin: row[6].to_s.strip, pinyin: row[9].to_s.strip}
      end

      rows
    end

    def audio_prefix(archive, scope)
      listing = `unzip -Z1 #{Shellwords.escape(archive.to_s)} 2>/dev/null | head -400`
      entry = listing.lines.map(&:chomp).find { |line| line =~ %r{(?:\A|/)#{scope[:dir]}/[^/]+\.wav\z} }
      abort("cannot find #{scope[:dir]}/ inside #{archive.basename}") if entry.nil?

      prefix = entry[/\A(.*?)#{scope[:dir]}/, 1].to_s
      puts("  audio lives at #{prefix}#{scope[:dir]}/")
      prefix
    end

    def extract_wavs(archive, scope, rows, into, prefix)
      into.mkpath
      missing = rows.reject { |row| into.join("#{prefix}#{scope[:dir]}", "#{row[:id]}.wav").exist? }
      if missing.empty?
        puts("  all #{rows.size} wav files already extracted")
        return
      end

      puts("  extracting #{missing.size} of #{rows.size} wav files")
      missing.each_slice(400).with_index do |batch, index|
        patterns = batch.map { |row| "#{prefix}#{scope[:dir]}/#{row[:id]}.wav" }
        system("unzip", "-o", "-q", archive.to_s, *patterns, "-d", into.to_s)
        seen = [(index + 1) * 400, missing.size].min
        puts("    #{seen}/#{missing.size} (#{(seen * 100.0 / missing.size).round}%)")
      end
    end

    def transcode(rows, scope, source_root, stage, prefix)
      stage.join("audio").mkpath
      index = {}
      done = 0
      skipped = 0
      queue = Queue.new
      rows.each { |row| queue << row }
      mutex = Mutex.new

      pool = Array.new(moe_workers) {
        Thread.new do
          while (row = begin
              queue.pop(true)
            rescue
              nil
            end)
            source = source_root.join("#{prefix}#{scope[:dir]}", "#{row[:id]}.wav")
            unless source.exist?
              mutex.synchronize { skipped += 1 }
              next
            end

            target = stage.join("audio", "#{row[:id]}.opus")
            unless target.exist?
              system(
                "ffmpeg",
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                source.to_s,
                "-c:a",
                "libopus",
                "-b:a",
                BITRATE,
                "-ac",
                "1",
                "-application",
                "voip",
                target.to_s,
                exception: true
              )
            end

            cut = head_ms(source)
            mutex.synchronize do
              (index[row[:text]] ||= []) <<
                {
                  "id" => row[:id],
                  "zhuyin" => row[:zhuyin],
                  "pinyin" => row[:pinyin],
                  "head_ms" => cut
                }
              done += 1
              puts("    #{done}/#{rows.size} (#{(done * 100.0 / rows.size).round}%)") if (done % REPORT_EVERY).zero?
            end
          end
        end
      }
      pool.each(&:join)

      [index, done, skipped]
    end

    def build_scope(scope_name)
      require "roo"
      require "shellwords"
      require "etc"
      require "fileutils"

      scope = SCOPES.fetch(scope_name)
      stage = Pathname(ENV.fetch("MOE_STAGE", "tmp/#{scope[:stage]}"))
      started = Time.now

      abort("ffmpeg not found — brew install ffmpeg") unless system("which ffmpeg > /dev/null 2>&1")

      step("1/6 fetching sources")
      fetch_notice
      dict = fetch(DICT_ZIP, work_dir)
      parts = scope[:parts].map { |name| fetch(name, work_dir) }

      step("2/6 unpacking the dictionary")
      unless work_dir.join("dict").exist?
        system("unzip", "-o", "-q", dict.to_s, "-d", work_dir.join("dict").to_s, exception: true)
      end

      puts("  ready")
      archive = parts.size == 1 ? parts.first : join_parts(parts, work_dir.join("www_joined.zip"))

      step("3/6 matching against our lexemes")
      wanted = Lexeme.pluck(:text).to_set
      rows = dictionary_rows(scope, wanted)
      abort("nothing matched — is the dictionary imported?") if rows.empty?
      puts("  #{rows.size} entries matched")

      step("4/6 extracting audio")
      prefix = audio_prefix(archive, scope)
      extract_wavs(archive, scope, rows, work_dir.join("wav"), prefix)

      step("5/6 transcoding to opus with #{moe_workers} workers")
      index, done, skipped = transcode(rows, scope, work_dir.join("wav"), stage, prefix)
      puts("  #{done} converted, #{skipped} had no audio in the archive")

      step("6/6 writing the index and the licence notice")
      notice = work_dir.join(NOTICE)
      FileUtils.cp(notice, stage.join("notice.pdf")) if notice.exist?
      stage.join("ATTRIBUTION.txt").write(
        [
          Huayu::MoeAudio::ATTRIBUTION,
          Huayu::MoeAudio::SOURCE_URL,
          "版本編號: #{VERSION}",
          "CC BY-ND 3.0 TW  https://creativecommons.org/licenses/by-nd/3.0/tw/legalcode",
          "Files are redistributed unmodified. Playback is bounded to the headword by the application.",
          "使用說明: notice.pdf (retained in full as the licence requires)"
        ].join("\n") +
          "\n"
      )
      index.each_value { |readings| readings.sort_by! { |reading| reading["id"] } }
      readings = index.values.sum(&:size)
      multi = index.count { |_text, list| list.size > 1 }
      payload = {"version" => VERSION, "scope" => scope_name, "entries" => index}
      stage.join("index.json").write(JSON.pretty_generate(payload))

      total = stage.join("audio").glob("*.opus").sum(&:size)
      remote = "/var/data/moe_audio#{scope_name == "chars" ? "" : "_words"}"
      puts("\n#{index.size} entries, #{readings} readings (#{multi} with more than one)")
      puts("#{human(total)} staged in #{stage}, took #{(Time.now - started).round}s")
      puts("\nupload with:")
      puts("  tar cf - -C #{stage} . | ssh -o UpdateHostKeys=no USER@HOST \\")
      puts("    'mkdir -p #{remote} && tar xf - -C #{remote}'")
    end

    desc("Recompute the head boundaries from the wav files already unpacked (no re-download, no re-transcode)")
    task(reindex: :environment) do
      require "roo"
      require "shellwords"
      require "etc"

      SCOPES.each_key do |name|
        scope = SCOPES.fetch(name)
        stage = Pathname("tmp/#{scope[:stage]}")
        next puts("#{name}: nothing staged, skipping") unless stage.join("index.json").exist?

        prefix = name == "chars" ? "" : "dict_concised_www_2014_#{VERSION}/"
        root = work_dir.join("wav", "#{prefix}#{scope[:dir]}")
        next puts("#{name}: wav files are gone from #{root}, skipping") unless root.exist?

        data = JSON.parse(stage.join("index.json").read)
        entries = data["entries"]
        total = entries.values.sum(&:size)
        step("recomputing #{total} boundaries for #{name}")

        done = 0
        mutex = Mutex.new
        queue = Queue.new
        entries.each { |text, readings| readings.each { |reading| queue << [text, reading] } }

        Array
          .new(moe_workers) {
            Thread.new do
              while (pair = begin
                  queue.pop(true)
                rescue
                  nil
                end)
                _text, reading = pair
                wav = root.join("#{reading["id"]}.wav")
                reading["head_ms"] = head_ms(wav) if wav.exist?
                mutex.synchronize do
                  done += 1
                  puts("    #{done}/#{total} (#{(done * 100.0 / total).round}%)") if (done % REPORT_EVERY).zero?
                end
              end
            end
          }
          .each(&:join)

        stage.join("index.json").write(JSON.pretty_generate(data))
        values = entries.values.flatten.filter_map { |r| r["head_ms"] }.sort
        puts(
          "  #{name}: median #{values[values.size / 2]}ms, p95 #{values[(values.size * 0.95).to_i]}ms, max #{values.last}ms"
        )
      end

      puts("\nre-upload only index.json for each scope")
    end

    desc("Prepare MOE single-character audio (local, needs ffmpeg)")
    task(chars: :environment) { build_scope("chars") }

    desc("Prepare MOE word audio (local, needs ffmpeg, ~40 GB scratch)")
    task(words: :environment) { build_scope("words") }

    desc("Report what is staged locally")
    task(status: :environment) do
      SCOPES.each_key do |name|
        stage = Pathname("tmp/#{SCOPES[name][:stage]}")
        index = stage.join("index.json")
        unless index.exist?
          puts("#{name}: nothing staged")
          next
        end

        data = JSON.parse(index.read)
        clips = stage.join("audio").glob("*.opus")
        puts("#{name}: #{data["entries"].size} entries, #{clips.size} clips, #{human(clips.sum(&:size))}")
      end
    end
  end
end
