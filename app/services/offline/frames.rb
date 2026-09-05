# frozen_string_literal: true

require "json"

module Offline
  module Frames
    HEADER = "Q>"
    HEADER_BYTES = 8

    module_function

    def write(io, object)
      payload = JSON.generate(object)
      io.write([payload.bytesize].pack(HEADER), payload)
      io.flush
    end

    def read(io)
      header = io.read(HEADER_BYTES)
      return nil unless header&.bytesize == HEADER_BYTES

      size = header.unpack1(HEADER)
      body = io.read(size)
      return nil unless body&.bytesize == size

      JSON.parse(body.force_encoding(Encoding::UTF_8))
    end
  end
end
