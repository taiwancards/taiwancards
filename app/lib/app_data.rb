# frozen_string_literal: true

module AppData
  MIRRORED_DIRS = %w[huayu dictionaries].freeze

  EXCLUDED_PREFIXES = [].freeze

  def self.excluded?(relative_path)
    EXCLUDED_PREFIXES.any? { |prefix| relative_path.to_s.start_with?(prefix) }
  end

  def self.own_root
    Rails.root.join("data")
  end

  def self.reference_root
    Rails.root.join("dict_and_corpora")
  end

  def self.local_roots
    [own_root, reference_root]
  end

  def self.root
    Pathname(ENV.fetch("DATA_ROOT") { own_root.to_s })
  end

  def self.external?
    ENV["DATA_ROOT"].present? && root.to_s != own_root.to_s
  end

  def self.roots
    external? ? [root, *local_roots] : local_roots
  end

  def self.target_path(relative)
    root.join(relative)
  end

  def self.path(relative)
    candidates = roots
    base = candidates.find { |candidate| candidate.join(relative).exist? }
    (base || candidates.first).join(relative)
  end

  def self.glob(pattern)
    roots.flat_map { |base| base.glob(pattern) }
  end

  def self.media_root
    Pathname(ENV.fetch("MEDIA_ROOT") { ENV["DATA_ROOT"].presence || Rails.root.join("media").to_s })
  end

  def self.media_path(relative)
    media_root.join(relative)
  end
end
