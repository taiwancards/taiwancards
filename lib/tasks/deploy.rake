# frozen_string_literal: true

namespace(:deploy) do
  desc("Import committed data sources that changed since the last boot (idempotent, no-op when unchanged)")
  task(sync: :environment) do
    puts(Deploy::Sync.new.call)
  end

  desc("Download everything the running app reads from the runtime bucket. Usage: rake deploy:hydrate")
  task(hydrate: :environment) do
    Deploy::Hydrator.new.call
  end

  desc("Fill glosses, parts of speech and register mix from the dictionary already in the database")
  task(fillers: :environment) do
    failed = Deploy::Fillers.new.call
    abort("deploy:fillers FAILED [#{failed.join(", ")}]") if failed.any?
  end

  desc("Ask Render to build and roll out the current commit. Usage: rake deploy:release")
  task(release: :environment) do
    deploy = Render::Api.new.deploy!
    puts("release: #{deploy.fetch("id")} #{deploy.fetch("status")} — watch it in the Render dashboard")
  end
end
