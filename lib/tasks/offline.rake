# frozen_string_literal: true

namespace(:offline) do
  desc("Render the guest pages into storage/packs as downloadable offline packs")
  task(:build, [:only] => :environment) do |_task, args|
    only = [args[:only], *args.extras].compact_blank
    Offline::Builder.new(workers: Offline::Pool.workers).call(only: only.presence)
  end

  desc("Show what the built packs hold")
  task(list: :environment) do
    file = Offline.root.join(Offline::MANIFEST)
    abort("offline: nothing built yet, run rails offline:build") unless file.exist?

    manifest = JSON.parse(file.read)
    manifest.fetch("packs").each do |pack|
      bytes = pack["bytes"].to_h.values.sum
      puts(format("%-16s %6d pages  %8.1f MB  %s", pack["id"], pack["pages"], bytes / 1_048_576.0, pack["digest"]))
    end
    puts("built at #{manifest["built_at"]}")
  end
end
