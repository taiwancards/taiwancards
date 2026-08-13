# frozen_string_literal: true

module FontAssets
  MOUNT = "/fonts"
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  CACHE_CONTROL = "public, max-age=31536000, immutable"
  KAI_CORE = "tw-kai-core.woff2"
  KAI_SLICES = "tw-kai-[0-9]*.woff2"

  module_function

  def directory
    Pathname.new(ENV.fetch("FONT_DIR", File.expand_path("../storage/fonts", __dir__)))
  end

  def installed?
    directory.exist? && directory.glob("*.woff2").any?
  end

  def kai_installed?
    kai_faces.size > 1 && kai_faces.all? { |file| file.exist? && file.size.positive? }
  end

  def kai_faces
    [directory.join(KAI_CORE), *directory.glob(KAI_SLICES).sort]
  end

  def base_url = SharedAssets.base_url

  def url_for(name) = SharedAssets.url_for("fonts", name)

  def forget_stamps! = SharedAssets.forget_stamps!

  def kai_core_url
    url_for(KAI_CORE)
  end
end
