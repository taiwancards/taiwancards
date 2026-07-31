# frozen_string_literal: true

namespace(:i18n) do
  desc("Compare the application locales key by key, including interpolation names")
  task(check: :environment) do
    problems = LocaleParity.new.problems
    abort("i18n: #{problems.length} problem(s)\n  #{problems.join("\n  ")}") if problems.any?

    puts("i18n: locales agree")
  end
end
