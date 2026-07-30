# frozen_string_literal: true

namespace :deploy do
  def push_kinds = Deploy::DictionaryDump::KINDS

  desc("Push the local dictionary straight into a remote database. Usage: PROD_DATABASE_URL=… rake deploy:push")
  task(:push, [:kinds] => :environment) do |_t, args|
    url = ENV["PROD_DATABASE_URL"].presence || abort("PROD_DATABASE_URL is required")
    kinds = (args[:kinds].presence&.split("+") || push_kinds).map(&:strip)
    unknown = kinds - push_kinds
    abort("unknown kind: #{unknown.join(", ")}") if unknown.any?
    dump = Rails.root.join("tmp", "push-dictionary.tsv")
    dump.dirname.mkpath

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rows = Deploy::DictionaryDump.new(kinds).write(dump)
    puts(format("dumped %d rows (%s) in %.1fs", rows, dump.size.to_fs(:human_size), Process.clock_gettime(Process::CLOCK_MONOTONIC) - started))
    abort("nothing to push") if rows.zero?

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Deploy::DictionaryPush.new(url, dump, kinds).call
    puts(format("pushed in %.1fs", Process.clock_gettime(Process::CLOCK_MONOTONIC) - started))
  ensure
    dump&.delete if dump&.exist?
  end
end
