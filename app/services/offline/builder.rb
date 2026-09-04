# frozen_string_literal: true

module Offline
  class Builder
    CHUNK_BYTES = 4_000_000
    VERSION = 1
    REFUSAL_SHARE = 0.01

    def initialize(root: Offline.root, io: $stdout, renderer: Renderer.new)
      @root = Pathname(root)
      @io = io
      @renderer = renderer
    end

    def call(only: nil)
      wanted = only.present? ? Sections.all.select { |section| only.include?(section.id) } : Sections.all
      raise "offline:build knows no section named #{only.join(", ")}" if wanted.empty?

      @root.mkpath
      manifest = existing_manifest

      Offline.while_rendering do
        wanted.each do |section|
          manifest[section.id] = build(section, manifest[section.id])
          save_manifest(manifest)
        end
      end

      report(manifest)
      sweep(manifest)
      manifest
    end

    private

    attr_reader :root, :io, :renderer

    def build(section, previous)
      @refused = []
      pages = Pages.new(section).call
      stamp = Freshness.new.digest(section, pages.paths)

      if previous && previous["stamp"] == stamp && carried?(previous)
        io.puts("  #{section.id}: unchanged")
        return previous
      end

      rendered = render_all(section, pages.paths)
      settle_refusals(section, pages.paths)
      digest = Digest::SHA256.hexdigest(Marshal.dump(rendered))[0, 8]

      record(section, pages, rendered, digest, stamp)
    end

    def render_all(section, paths)
      I18n.available_locales.to_h do |locale|
        io.print("  #{section.id}: #{locale} 0/#{paths.size}\r")
        [locale.to_s, render_locale(section, paths, locale)]
      end
    end

    def render_locale(section, paths, locale)
      done = 0
      paths.each_with_object({}) do |path, acc|
        fragment = render_one(path, locale)
        acc["/#{locale}#{path}"] = fragment if fragment
        done += 1
        io.print("  #{section.id}: #{locale} #{done}/#{paths.size}\r") if (done % 25).zero?
      end
    end

    def render_one(path, locale)
      Fragment.new(renderer.call(path, locale)).call
    rescue Renderer::Refused => e
      @refused << e.message
      nil
    end

    def settle_refusals(section, paths)
      return if @refused.empty?

      wanted = paths.size * I18n.available_locales.size
      io.puts("  #{section.id}: #{@refused.size} page(s) refused")
      @refused.first(5).each { |message| io.puts("    #{message}") }

      return if @refused.size <= wanted * REFUSAL_SHARE

      raise "#{section.id}: #{@refused.size} of #{wanted} pages refused, too many to publish"
    end

    def write_shells(section, digest)
      return nil unless section.id == Sections::CORE

      name = "shells-#{digest}.json"
      root.join(name).write(JSON.generate(Shells.new.call))
      name
    end

    def record(section, pages, rendered, digest, stamp)
      chunks = {}
      bytes = {}

      rendered.each do |locale, fragments|
        written = write_chunks(section, digest, locale, fragments)
        chunks[locale] = written.map(&:first)
        bytes[locale] = written.sum(&:last)
      end

      index = write_index(section, digest, pages.entries)
      shells = write_shells(section, digest)
      io.puts("  #{section.id}: #{rendered.values.sum(&:size)} pages, #{human(bytes.values.sum)}      ")

      {
        "id" => section.id,
        "group" => section.group,
        "level" => section.level,
        "titles" => titles(section),
        "digest" => digest,
        "stamp" => stamp,
        "pages" => rendered.values.first&.size.to_i,
        "chunks" => chunks,
        "bytes" => bytes,
        "index" => index,
        "shells" => shells
      }
    end

    def write_chunks(section, digest, locale, fragments)
      batches(fragments).each_with_index.map do |batch, position|
        name = "#{section.id}-#{digest}.#{locale}.#{position}.json"
        payload = JSON.generate(batch)
        root.join(name).write(payload)
        [name, payload.bytesize]
      end
    end

    def batches(fragments)
      groups = [{}]
      size = 0

      fragments.each do |path, fragment|
        weight = path.bytesize + fragment.values.sum(&:bytesize)

        if size + weight > CHUNK_BYTES && groups.last.any?
          groups << {}
          size = 0
        end

        groups.last[path] = fragment
        size += weight
      end

      groups.reject(&:empty?)
    end

    def write_index(section, digest, entries)
      return nil if entries.empty?

      name = "#{section.id}-#{digest}.index.json"
      root.join(name).write(JSON.generate({"pack" => section.id, "rows" => entries.map(&:to_row)}))
      name
    end

    def titles(section)
      return I18n.available_locales.to_h { |locale| [locale.to_s, level_title(section)] } if section.levelled?

      I18n.available_locales.to_h { |locale| [locale.to_s, section.title(locale)] }
    end

    def level_title(section)
      Collection.find_by(kind: :tocfl, level_tag: section.level)&.name || section.level
    end

    def existing_manifest
      file = root.join(Offline::MANIFEST)
      return {} unless file.exist?

      JSON.parse(file.read).fetch("packs", []).index_by { |pack| pack["id"] }
    rescue JSON::ParserError
      {}
    end

    def carried?(pack)
      files = [*pack["chunks"].to_h.values.flatten, pack["index"], pack["shells"]].compact
      files.all? { |name| root.join(name).exist? }
    end

    def save_manifest(manifest)
      payload = {
        "version" => VERSION,
        "built_at" => Time.current.utc.iso8601,
        "packs" => ordered(manifest)
      }

      root.join(Offline::MANIFEST).write(JSON.pretty_generate(payload))
    end

    def report(manifest)
      packs = ordered(manifest)
      io.puts("offline: #{packs.size} packs, #{human(packs.sum { |pack| pack["bytes"].to_h.values.sum })}")
    end

    def ordered(manifest) = Sections.ids.filter_map { |id| manifest[id] }

    def sweep(manifest)
      kept = manifest
        .values
        .flat_map { |pack| [*pack["chunks"].to_h.values.flatten, pack["index"], pack["shells"]] }
        .compact
        .to_set
      kept << Offline::MANIFEST

      root.glob("*.json").each do |file|
        next if kept.include?(file.basename.to_s)

        file.delete
      end
    end

    def human(bytes) = format("%.1f MB", bytes / 1_048_576.0)
  end
end
