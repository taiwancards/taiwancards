# frozen_string_literal: true

module PrecompressedAssets
  EXTENSIONS = %w[css js svg].freeze
  QUALITY = 11

  module_function

  def write(directory)
    Pathname.new(directory).glob("**/*.{#{EXTENSIONS.join(",")}}").count do |file|
      target = Pathname.new("#{file}.br")
      next false if target.exist?

      compressed = Brotli.deflate(file.binread, quality: QUALITY)
      next false if compressed.bytesize >= file.size

      target.binwrite(compressed)
      true
    end
  end
end
