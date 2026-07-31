# frozen_string_literal: true

module Collections
  class Selection
    RADIX = 36
    SEPARATOR = ","
    MAX_LENGTH = 16_384

    class << self
      def pack(ids)
        Array(ids).map { |id| id.to_i.to_s(RADIX) }.join(SEPARATOR)
      end

      def unpack(packed, limit:)
        return [] if packed.blank? || packed.length > MAX_LENGTH

        packed
          .to_s
          .split(SEPARATOR, limit + 1)
          .first(limit)
          .filter_map { |chunk| chunk.to_i(RADIX).presence }
          .uniq
      end
    end
  end
end
