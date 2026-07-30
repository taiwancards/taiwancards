# frozen_string_literal: true

module Site
  class Counts
    KEY = "landing/counts/v6"
    TTL = 12.hours
    KINDS = %i[radicals characters words collocations sentences].freeze

    class << self
      def fetch
        Rails.cache.fetch(KEY, expires_in: TTL) { compute }
      end

      def warm!
        Rails.cache.write(KEY, compute, expires_in: TTL)
      end

      def reset!
        Rails.cache.delete(KEY)
      end

      def compute
        counted = Lexeme.unrestricted.group(:kind).count
        KINDS.index_with { |name| counted[name.to_s.singularize].to_i }
      end
    end
  end
end
