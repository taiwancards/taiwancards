# frozen_string_literal: true

class NewsletterImage < ApplicationRecord
  TYPES = {"image/png" => "png", "image/jpeg" => "jpg", "image/gif" => "gif"}.freeze
  MAX_BYTES = 1024 * 1024

  belongs_to :newsletter

  validates :content_type, inclusion: {in: TYPES.keys}
  validates :byte_size, numericality: {greater_than: 0, less_than_or_equal_to: MAX_BYTES}

  def self.from_upload(newsletter, upload)
    data = upload.read
    newsletter.images.new(
      content_type: upload.content_type.to_s,
      filename: "image-#{SecureRandom.hex(4)}.#{TYPES.fetch(upload.content_type.to_s, "bin")}",
      data:,
      byte_size: data.bytesize
    )
  end
end
