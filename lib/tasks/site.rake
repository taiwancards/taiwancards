# frozen_string_literal: true

namespace(:site) do
  desc("Render the public pages into site/ for the static service")
  task(build: :environment) do
    Site::Exporter.new.call
  end
end
