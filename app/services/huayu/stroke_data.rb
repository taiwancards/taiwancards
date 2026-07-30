# frozen_string_literal: true

module Huayu
  class StrokeData
    PATH = AppData.path("dictionaries/makemeahanzi/graphics.txt")

    class << self
      def raw(char)
        offset, length = index[char]
        return nil if offset.nil?

        IO.read(PATH, length, offset)
      end

      def available?
        PATH.exist?
      end

      def has?(char)
        index.key?(char)
      end

      def reset!
        @index = nil
      end

      private

      def index
        @index ||= build_index
      end

      def build_index
        return {} unless PATH.exist?

        map = {}
        offset = 0
        File.open(PATH, "rb") do |file|
          file.each_line do |line|
            match = line.match(/\A\{"character":"(.+?)"/)
            map[match[1].force_encoding("UTF-8")] = [offset, line.bytesize] if match
            offset += line.bytesize
          end
        end

        map
      end
    end
  end
end
