# frozen_string_literal: true

module SharedAssets
  MOUNTS = %w[fonts json packs].freeze
  PACKS = "packs"
  MANIFEST = "manifest.json"
  MANIFEST_CACHE_CONTROL = "public, max-age=60"

  module_function

  def base_url
    ENV["ASSETS_BASE_URL"].presence&.chomp("/")
  end

  def root
    FontAssets.directory.dirname
  end

  def directory(mount)
    root.join(mount)
  end

  def url_for(mount, name)
    path = "/#{mount}/#{name}"
    return path if base_url.nil?

    "#{base_url}#{path}#{stamp(mount, name)}"
  end

  def stamp(mount, name)
    @stamps ||= {}
    @stamps["#{mount}/#{name}"] ||= begin
      file = directory(mount).join(name)
      file.exist? ? "?v=#{Digest::SHA256.file(file).hexdigest[0, 8]}" : ""
    end
  end

  def carried?(mount, name)
    base_url.present? || directory(mount).join(name).exist?
  end

  def forget_stamps! = @stamps = nil
end
