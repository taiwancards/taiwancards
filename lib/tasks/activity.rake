# frozen_string_literal: true

namespace(:activity) do
  desc("Delete activity events older than the retention window")
  task(prune: :environment) do
    puts("pruned #{ActivityEvent.prune_all} old event(s)")
  end
end
