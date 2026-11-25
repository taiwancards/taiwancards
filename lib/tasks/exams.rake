# frozen_string_literal: true

namespace(:exams) do
  desc("Summarize the TOCFL paper bundles into data/huayu/tocfl_bundles.json for the exam hall")
  task(bundles: :environment) do
    source = Huayu::TocflBundles.source_root
    abort("exams: no bundles under #{source}") unless source.directory?

    bundles = Huayu::TocflBundles.write!(source:)
    bundles.each { |slug, row| puts(format("  %-24s %s  %2d questions", slug, row["digest"], row["count"].to_i)) }

    conflicts = Huayu::TocflBundles.key_conflicts(source:)
    missing = Huayu::TocflBundles.missing_audio(source:) + Huayu::TocflBundles.missing_papers(source:)
    conflicts.each { |line| warn("  key differs: #{line}") }
    missing.each { |line| warn("  file missing: #{line}") }

    puts("exams: #{bundles.size} bundle(s) written to #{AppData.target_path(Huayu::TocflBundles::MANIFEST_PATH)}")
    abort("exams: #{conflicts.size} key conflict(s), #{missing.size} missing file(s)") if conflicts.any? || missing.any?
  end
end
