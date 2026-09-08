# frozen_string_literal: true

namespace(:content) do
  desc("Bring the local mirror to the production content and snapshot it")
  task(refresh: :environment) do
    Deploy::ContentPush.from_env.refresh
  end

  desc("Show what a push would change in production, without touching it")
  task(plan: :environment) do
    push = Deploy::ContentPush.from_env
    push.print(push.plan(cascade: Deploy::ContentPush.cascade?))
  rescue Deploy::ContentPush::Refused => e
    abort("plan refused: #{e.message}")
  end

  desc("Push the mirror content to production in one verified transaction")
  task(push: :environment) do
    push = Deploy::ContentPush.from_env
    push.print(push.push(cascade: Deploy::ContentPush.cascade?))
  rescue Deploy::ContentPush::Refused, Deploy::ContentDiff::Mismatch => e
    abort("push refused: #{e.message}")
  end

  desc("Refresh the derived caches and the edge after a push; run against the production database")
  task(finish: :environment) do
    Deploy::DerivedCaches.refresh
    if Deploy::DerivedCaches.edge_configured?
      Deploy::DerivedCaches.purge_edge
      puts("finish: caches rebuilt, edge purged")
    else
      puts("finish: caches rebuilt, edge purge unconfigured")
    end
  end
end
