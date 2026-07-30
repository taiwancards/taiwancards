# frozen_string_literal: true

namespace(:install) do
  desc("Rebuild the whole local database from source files. Usage: CONFIRM=yes rake install:local")
  task(local: :environment) do
    Install::Runner.new.call
  end

  desc("Re-run the closing census and integrity checks on the database as it stands")
  task(verify: :environment) do
    Install::Runner.new.verify
  end

  desc("Report the hardware the rebuild will run on")
  task(hardware: :environment) do
    Install::Hardware.report($stdout)
  end
end
