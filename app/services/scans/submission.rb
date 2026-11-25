# frozen_string_literal: true

module Scans
  class Submission
    MAX_PARTS = 3
    TALL_RATIO = 2.5

    attr_reader :parts, :error

    def self.files_from(params)
      photos = params[:photos]
      photos.is_a?(Array) ? photos : [params[:photo]].compact
    end

    def initialize(files)
      files = Array(files)
      if files.size > MAX_PARTS
        @parts = []
        @error = "too_large"
      else
        @parts = files.map { |file| Upload.new(file) }
        @error = parts.empty? ? "missing" : parts.filter_map(&:error).first
      end
    end

    def valid? = error.nil?

    def size = parts.sum(&:size)

    def width = parts.map(&:width).max

    def height = parts.sum(&:height)

    def images = parts.map(&:base64)
  end
end
