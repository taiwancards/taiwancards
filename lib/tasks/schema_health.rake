# frozen_string_literal: true

namespace(:db) do
  desc("Report foreign keys that no index leads with")
  task(health: :environment) do
    unindexed = SchemaHealth.new.unindexed_foreign_keys

    if unindexed.any?
      abort("db: #{unindexed.length} foreign key(s) without a leading index\n  #{unindexed.join("\n  ")}")
    end

    puts("db: every foreign key is indexed")
  end
end
