# frozen_string_literal: true

PRONUNCIATION_INVOCATION = lambda do |task|
  names = task.arg_names
  names.empty? ? "rake #{task.name}" : "rake #{task.name}[#{names.join(",")}]"
end

desc("List every pronunciation task")
task(pronunciation: "pronunciation:help")

VOICES = lambda { ENV["VOICES"].presence&.to_sym || :fitting }

namespace(:pronunciation) do
  desc("Show all tasks in this namespace")
  task(:help) do
    rows = Rake.application.tasks.select { |t| t.name.start_with?("pronunciation:") && t.name != "pronunciation:help" }

    width = rows.map { |t| PRONUNCIATION_INVOCATION.call(t).length }.max.to_i

    puts("Pronunciation tasks\n\n")
    rows.sort_by(&:name).each do |t|
      puts(format("  %-#{width}s  %s", PRONUNCIATION_INVOCATION.call(t), t.comment))
    end

    puts(
      <<~USAGE

        The server argument is the part before @ in the SSH host:
          ssh srv-abc123@ssh.singapore.render.com
              ^^^^^^^^^^
        Both abc123 and srv-abc123 are accepted. Default region: singapore.

        Usual order:
          rake pronunciation:check_local          what is ready locally
          rake pronunciation:sync_check[abc123]   what would change, no upload
          rake pronunciation:sync[abc123]         upload

        If the connection fails:
          rake pronunciation:ssh_debug[abc123]    full ssh log
      USAGE
    )
  end

  desc("Corpus audio to per-token features. KEYS limits the run to a comma-separated list")
  task(ingest: :environment) do
    only = ENV["KEYS"].presence&.split(",")
    Pronunciation::Corpus::Ingest.new(only: only, io: $stdout).write!
    Pronunciation::Corpus::SpeakerPitch.reset!
  end

  desc("Rebuild corpus_cv from Common Voice zh-TW. ARCHIVE=path to an official release, else the public mirror")
  task(common_voice: :environment) do
    Pronunciation::Corpus::CommonVoiceBuilder
      .new(
        archive: ENV["ARCHIVE"].presence,
        repo: ENV["REPO"].presence || Pronunciation::Corpus::CommonVoiceBuilder::REPO,
        release: ENV["RELEASE"].presence || Pronunciation::Corpus::CommonVoiceBuilder::RELEASE,
        io: $stdout
      )
      .build!
  end

  desc("Common Voice zh-TW clips to syllable tokens, so the templates hear many Taiwanese voices")
  task(common_voice_tokens: :environment) do
    Pronunciation::Corpus::CommonVoiceTokens.new(io: $stdout).write!
  end

  desc("Mark every Common Voice speaker as unheard, so VOICES=held_out reports on a stranger")
  task(speaker_split: :environment) do
    Pronunciation::Corpus::SpeakerSplit.new(io: $stdout).write!
  end

  desc("Median pitch of each corpus speaker, the reference the tone register is measured against")
  task(speaker_pitch: :environment) do
    Pronunciation::Corpus::SpeakerPitch.build!.each { |name, hz| puts(format("  %-14s %.1f Hz", name, hz)) }
  end

  desc("Pool voice onset time by initial so syllables with thin evidence borrow from their class")
  task(vot_norms: :environment) do
    Pronunciation::Corpus::VotNorms.build!.sort_by { |_, v| v["median"] }.each do |initial, stat|
      puts(
        format(
          "  %-3s n=%-5d median %6.1f ms  spread %5.1f",
          initial,
          stat["n"],
          stat["median"],
          stat["mad"]
        )
      )
    end
  end

  desc("Per-token features to reference templates. STYLE=citation|word|word_initial|word_medial|word_final")
  task(templates: :environment) do
    styles = ENV["STYLE"].presence&.split(",") || Pronunciation::Corpus::TemplateBuilder::STYLES.keys
    styles.each do |style|
      puts("#{style}:")
      builder = Pronunciation::Corpus::TemplateBuilder.new(style: style, io: $stdout)
      built = builder.call
      builder.write_index!(built) if style == "citation"
    end

    Pronunciation::TemplateStore.reset!
  end

  desc("Pause, pitch step and energy dip at every syllable junction of native connected speech")
  task(junction_norms: :environment) do
    Pronunciation::Corpus::JunctionNorms.new(io: $stdout).write!
    Pronunciation::Acoustic::Junctions.reset!
  end

  desc("Measure how much wider connected speech scatters than a citation form (MOE, one voice)")
  task(style_factor: :environment) do
    Pronunciation::Corpus::StyleFactor.new.write!
  end

  desc("Re-measure how far speakers naturally differ, from Common Voice (needs style_factor)")
  task(variability: :environment) do
    Pronunciation::Corpus::VariabilityBuilder.new.write!
  end

  desc("Score every syllable against its own rivals: how well we recognise it at all")
  task(syllable_quality: :environment) do
    rows = Pronunciation::Corpus::SyllableQuality.new(part: ENV["SPLIT"].presence || "all").write!
    good = rows.count { |r| r["self"] >= 80 && r["top1"] >= 80 && r["margin"] >= 5 }
    puts("measured #{rows.length}, usable for drills #{good}")
  end

  desc("How well each minimal pair is told apart, held out — the drill sections are picked from this")
  task(contrast_quality: :environment) do
    payload = Pronunciation::Corpus::ContrastQuality.new(io: $stdout).write!
    payload["pairs"].group_by { |pair| pair["family"] }.sort.each do |family, rows|
      usable = rows.count { |row| row["accuracy"] >= Pronunciation::Corpus::DrillsBuilder::DECIDABLE }
      puts(format("  %-10s %4d pairs, %3d decidable, best %.1f%%", family, rows.length, usable, rows.first["accuracy"]))
    end
  end

  desc("Build the drill sections from the syllables we actually recognise")
  task(drills: :environment) do
    payload = Pronunciation::Corpus::DrillsBuilder.new.write!
    payload["sections"].each do |section|
      puts(
        format(
          "  %-22s %-38s %3d %s",
          section["id"],
          section["title"]["ru"],
          section["n_items"],
          section["thin"] ? "THIN" : ""
        )
      )
    end
  end

  desc("Full local rebuild: audio to tokens to pooled norms to templates")
  task(rebuild: :environment) do
    %w[
      common_voice_tokens
      ingest
      speaker_split
      speaker_pitch
      vot_norms
      style_factor
      variability
      templates
      axis_norms
      thresholds_build
      syllable_quality
      contrast_quality
      drills
    ]
      .each do |name|
        puts("\n== #{name} ==")
        Rake::Task["pronunciation:#{name}"].invoke
      end
  end

  desc("Rebuild the per-axis scales from the corpus recordings (local, uses every core)")
  task(axis_norms: :environment) do
    Pronunciation::Corpus::AxisNormsBuilder.new(part: ENV["SPLIT"].presence || "dev").write!
    Pronunciation::AxisNorms.reset!
  end

  desc("Rebuild the color thresholds from the corpus recordings (local, uses every core)")
  task(thresholds_build: :environment) do
    payload = Pronunciation::Corpus::ThresholdsBuilder.new(part: ENV["SPLIT"].presence || "dev").write!
    payload["thresholds"].each do |cell, t|
      puts(
        format(
          "  %-9s green %3d  red %3d   holds %.1f%%  admits %.1f%%",
          cell,
          t["green"],
          t["red"],
          t["green_keeps"].to_f,
          t["green_admits"].to_f
        )
      )
    end
  end

  desc("Score every kind of wrong answer against every kind of speaker and check the order")
  task(ladder: :environment) do
    labels = {
      "tw_exact" => "Taiwan   · same syllable · same tone",
      "cn_exact" => "China · same syllable · same tone",
      "tw_near_tone" => "Taiwan   · same syllable · other tone",
      "tw_near_syllable" => "Taiwan   · near syllable · same tone",
      "tw_near_both" => "Taiwan   · near syllable · other tone",
      "tw_far_syllable" => "Taiwan   · other syllable · same tone",
      "tw_far_both" => "Taiwan   · other syllable · other tone",
      "cn_far_both" => "China · other syllable · other tone"
    }

    r = Pronunciation::Corpus::Ladder.new(part: ENV["SPLIT"].presence || "test", speakers: VOICES.call).call
    puts(
      format(
        "\n%-38s %7s %8s %6s %6s %8s %9s",
        "condition",
        "n",
        "median",
        "p25",
        "p75",
        "green",
        "red+"
      )
    )
    r["rungs"].sort_by { |x| -x["median"] }.each do |x|
      puts(
        format(
          "%-38s %7d %8d %6d %6d %7.1f%% %8.1f%%",
          labels[x["id"]],
          x["n"],
          x["median"],
          x["p25"],
          x["p75"],
          x["green"],
          x["red_or_worse"]
        )
      )
    end
  end

  desc("Measure quality on the held-out split: top-1, d prime, AUC, how natives fare")
  task(report_card: :environment) do
    r = Pronunciation::Corpus::ReportCard.new(part: ENV["SPLIT"].presence || "test", speakers: VOICES.call).call
    n = r["natives"]
    puts(format("\ntop-1 %.4f", r["top1"]["value"]))
    puts(
      format(
        "natives: median %d, p10 %d, green %.1f%%, red or worse %.1f%%",
        n["median"],
        n["p10"],
        n["green"],
        n["red_or_worse"]
      )
    )
    r["contrasts"].sort.each do |cell, c|
      next if c["n"].to_i < 30

      puts(
        format(
          "  %-8s d′ %5.2f  AUC %.4f  same %3d / other %3d  (n=%d)",
          cell,
          c["dprime"],
          c["auc"],
          c["self_median"],
          c["rival_median"],
          c["n"]
        )
      )
    end

    if ENV["OUT"].present?
      File.write(ENV["OUT"], JSON.pretty_generate(r))
      puts("Written: #{ENV["OUT"]}")
    end
  end

  desc("Sync pronunciation templates to a Render disk. Usage: rake pronunciation:sync[srv-12345]")
  task(:sync, %i[server region] => :environment) do |_t, args|
    if args[:server].blank?
      abort(
        <<~USAGE
          Specify the Render service.

            rake pronunciation:sync[srv-abc123]
            rake pronunciation:sync[abc123]
            rake pronunciation:sync[abc123,frankfurt]

          It is the part before @ in the SSH host:
            ssh srv-abc123@ssh.singapore.render.com
                ^^^^^^^^^^
          The second argument is the region, default singapore.
        USAGE
      )
    end

    sync = Pronunciation::Sync.new(
      server: args[:server],
      region: args[:region].presence || Pronunciation::Sync::DEFAULT_REGION
    )

    begin
      sync.call(dry_run: ENV["DRY_RUN"].present?)
    rescue StandardError => e
      abort("\nERROR: #{e.message}")
    end
  end

  desc("Remove leftovers of an interrupted sync (*.old, *.prev). Usage: rake pronunciation:cleanup[srv-12345]")
  task(:cleanup, %i[server region] => :environment) do |_t, args|
    abort("specify the service: rake pronunciation:cleanup[srv-abc123]") if args[:server].blank?

    sync = Pronunciation::Sync.new(
      server: args[:server],
      region: args[:region].presence || Pronunciation::Sync::DEFAULT_REGION
    )

    begin
      sync.cleanup(dry_run: ENV["DRY_RUN"].present?)
    rescue StandardError => e
      abort("\nERROR: #{e.message}")
    end
  end

  desc("Show what sync would change without sending anything")
  task(:sync_check, %i[server region] => :environment) do |_t, args|
    ENV["DRY_RUN"] = "1"
    Rake::Task["pronunciation:sync"].invoke(args[:server], args[:region])
  end

  desc("Download what is currently on Render into a local mirror. Usage: rake pronunciation:pull[srv-12345]")
  task(:pull, %i[server region] => :environment) do |_t, args|
    abort("specify the service: rake pronunciation:pull[srv-abc123]") if args[:server].blank?

    dest = ENV["DEST"].presence || Rails.root.join("tmp/render_mirror").to_s
    sync = Pronunciation::Sync.new(
      server: args[:server],
      region: args[:region].presence || Pronunciation::Sync::DEFAULT_REGION
    )

    begin
      sync.send(:check_ssh!)
      sync.send(:mirror!, dest)
      sync.send(:close_connection)
      files = Dir.glob(File.join(dest, "**", "*")).count { |f| File.file?(f) }
      puts("\nMirror: #{files} files in #{dest}")
      puts("Compare with local: diff -rq data/pronunciation #{dest} | head")
    rescue StandardError => e
      abort("\nERROR: #{e.message}")
    end
  end

  desc("Show the exact ssh command and its verbose output. Usage: rake pronunciation:ssh_debug[srv-12345]")
  task(:ssh_debug, %i[server region] => :environment) do |_t, args|
    abort("specify the service: rake pronunciation:ssh_debug[srv-abc123]") if args[:server].blank?

    sync = Pronunciation::Sync.new(
      server: args[:server],
      region: args[:region].presence || Pronunciation::Sync::DEFAULT_REGION
    )
    cmd = sync.send(:ssh_command, sync.host, "echo ok")

    puts("Command the task runs:\n  #{cmd.join(" ")}\n\n")
    puts("Same call with -v (full negotiation log):\n")
    system("ssh", "-v", *cmd[1..-3], sync.host, "echo ok")
    puts("\n\nWithout multiplexing and extra options:\n")
    system("ssh", "-o", "BatchMode=yes", "-o", "UpdateHostKeys=no", sync.host, "echo ok")
  end

  desc("Prune the raw attempt log. The accumulators in syllable_skills are kept forever")
  task(compact: :environment) do
    days = ENV.fetch("DAYS", 180).to_i
    before = PronunciationAttempt.count
    deleted = PronunciationAttempt.where(created_at: ...days.days.ago).delete_all

    puts("attempt log: #{before} rows, #{deleted} removed older than #{days} days")
    puts("accumulators: #{SyllableSkill.count} rows, #{SyllableSkill.sum(:n)} attempts in them")
  end

  desc("Show where each learner stands and what they should drill next")
  task(focus: :environment) do
    User.find_each do |user|
      focus = Pronunciation::Focus.new(user)
      summary = focus.summary
      next if summary.nil?

      puts(
        "\n#{user.email}: #{summary["attempts"]} attempts over #{summary["syllables"]} syllables, mean #{summary["average"]}"
      )
      focus.weaknesses.each do |row|
        puts(format("  %-10s %-4s %3d  n=%-4d %s", row["label"], row["zhuyin"], row["score"], row["n"], row["problem"]))
      end
    end
  end

  desc("Verify the local payload is complete before syncing")
  task(check_local: :environment) do
    source = Rails.root.join("data/pronunciation")
    missing = Pronunciation::Sync::PAYLOAD.reject { |e| File.exist?(source.join(e)) }

    if missing.any?
      abort("missing: #{missing.join(", ")}\nRebuild with: rake pronunciation:rebuild")
    end

    counts = {
      "taiwan" => Dir.glob(source.join("templates/taiwan/*.json")).length,
      "taiwan_wi" => Dir.glob(source.join("templates/taiwan_wi/*.json")).length,
      "taiwan_wm" => Dir.glob(source.join("templates/taiwan_wm/*.json")).length
    }
    drills = JSON.parse(File.read(source.join("drills.json")))
    sections = drills["sections"] || []

    puts("Local data is complete:")
    counts.each { |name, n| puts(format("  %-12s %5d templates", name, n)) }
    puts(
      format("  %-12s %5d sections (%d thin)", "drills", sections.length, sections.count { |s| s["thin"] })
    )
    puts(
      format(
        "  %-12s %5d syllables",
        "inventory",
        JSON.parse(File.read(source.join("inventory.json")))["keys"].length
      )
    )
  end
end
