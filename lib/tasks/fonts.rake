# frozen_string_literal: true

require "open-uri"

namespace(:fonts) do
  desc("Download the self-hosted webfonts listed in fonts.json into the font directory")
  task(install: :environment) do
    started = Time.current
    source = AppData.path("fonts.json")
    next puts("fonts: #{source} is missing, skipping") unless source.exist?

    manifest = JSON.parse(source.read)
    directory = FontAssets.directory
    FileUtils.mkdir_p(directory)

    missing = manifest.reject { |name, _| complete?(directory.join(name)) }
    next puts("fonts: #{manifest.size} present, nothing to download (#{elapsed(started)})") if missing.empty?

    failed = fetch_all(missing, directory)
    puts(
      "fonts: #{manifest.size} declared, #{missing.size - failed.size} downloaded, " \
        "#{failed.size} failed, in #{directory} (#{elapsed(started)})"
    )
    warn("fonts: first failure — #{failed.first}") if failed.any?
  end

  desc("Build the TW-Kai brush face as unicode-range slices, subset to the characters this dictionary uses")
  task(kai: :environment) do
    started = Time.current
    directory = FontAssets.directory
    next puts("fonts:kai already built in #{directory}") if FontAssets.kai_installed?

    Dir.mktmpdir do |workspace|
      workspace = Pathname.new(workspace)
      puts("fonts:kai preparing python")
      python = Fonts::KaiBuilder.new(workspace).prepare_python
      next puts("fonts:kai skipped — no usable python3 for subsetting") if python.nil?

      Fonts::KaiBuilder.new(workspace).call(python:, directory:)
    end

    puts("fonts:kai finished in #{elapsed(started)}")
  rescue => e
    puts("fonts:kai skipped — #{e.class}: #{e.message}")
  end
end

def complete?(path)
  path.exist? && path.size.positive?
end

def elapsed(started)
  "#{(Time.current - started).round(2)}s"
end

def fetch_all(entries, directory)
  queue = Queue.new
  entries.each { |pair| queue << pair }
  failed = Queue.new

  workers = Array.new([8, entries.size].min) do
    Thread.new do
      while (name, url = queue.pop(true) rescue nil)
        reason = fetch_one(name, url, directory)
        failed << "#{name}: #{reason}" if reason
      end
    end
  end

  workers.each(&:join)
  Array.new(failed.size) { failed.pop }
end

def fetch_one(name, url, directory)
  target = directory.join(name)
  partial = directory.join("#{name}.part")
  partial.binwrite(
    URI.parse(url).open("User-Agent" => FontAssets::USER_AGENT, :open_timeout => 10, :read_timeout => 30, &:read)
  )
  FileUtils.mv(partial, target)
  nil
rescue => e
  FileUtils.rm_f(partial)
  "#{e.class}: #{e.message}"
end
