# frozen_string_literal: true

desc(
  "Fully populate a fresh database: schema + ALL zh-TW dictionaries (open + Textbook) + admin account. One command for a clean deploy."
)
task(bootstrap: :environment) do
  puts("== Preparing schema ==")
  Rake::Task["db:prepare"].invoke

  puts("== Seeding settings and admin ==")
  Rake::Task["db:seed"].invoke

  puts("== Building all Huayu data (open + Textbook) ==")
  Rake::Task["huayu:build:all"].invoke

  puts("== Bootstrap complete ==")
end

namespace(:bootstrap) do
  desc("Only the freely-licensed open data (no Textbook), plus schema and admin")
  task(open: :environment) do
    Rake::Task["db:prepare"].invoke
    Rake::Task["db:seed"].invoke
    Rake::Task["huayu:build:open"].invoke
    puts("== Open bootstrap complete ==")
  end
end
