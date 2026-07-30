# frozen_string_literal: true

module ContentSources
  class Importer
    PATH = AppData.path("content_sources.json")

    def call
      entries.each { |entry| upsert(entry) }
      ContentSource.count
    end

    private

    def entries
      JSON.parse(File.read(PATH))
    end

    def upsert(entry)
      source = ContentSource.find_or_initialize_by(slug: entry.fetch("slug"))
      source.assign_attributes(entry.except("slug", "enabled", "enabled_for_admins"))
      source.enabled = entry.fetch("enabled", entry.fetch("license_commercial", false)) if source.new_record?
      source.enabled_for_admins = true if source.new_record?
      source.save!
      source
    end
  end
end
