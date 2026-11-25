# frozen_string_literal: true

require "fastimage"

module Scans
  class Upload
    TARGET_EDGE = 1600
    MAX_BYTES = 1_500_000
    MAX_EDGE = 2048
    MIN_EDGE = 64
    MAX_PIXELS = 3_200_000
    JPEG_MAGIC = "\xFF\xD8\xFF".b.freeze

    attr_reader :bytes, :width, :height, :error

    def initialize(file)
      @file = file
      @error = inspect_file
    end

    def valid? = error.nil?

    def size = bytes.bytesize

    def base64 = Base64.strict_encode64(bytes)

    private

    def inspect_file
      return "missing" unless @file.is_a?(ActionDispatch::Http::UploadedFile)
      return "too_large" if @file.size > MAX_BYTES

      @bytes = @file.read(MAX_BYTES + 1).to_s.b
      return "too_large" if @bytes.bytesize > MAX_BYTES
      return "not_image" unless @bytes.start_with?(JPEG_MAGIC)

      measure
    end

    def measure
      probe = FastImage.new(StringIO.new(@bytes))
      return "not_image" unless probe.type == :jpeg

      @width, @height = probe.size
      return "not_image" if @width.nil? || @height.nil?
      return "too_small" if [@width, @height].min < MIN_EDGE
      return "too_large" if [@width, @height].max > MAX_EDGE || @width * @height > MAX_PIXELS

      nil
    end
  end
end
