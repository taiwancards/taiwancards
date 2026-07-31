# frozen_string_literal: true

module Decks
  class Resolver
    class << self
      def ids_for(entry, index)
        Array(entry["items"]).filter_map { |kind, text| index[[kind.to_s, text]] }.uniq
      end
    end

    def call(entries)
      by_kind = Hash.new { |hash, key| hash[key] = [] }
      Array(entries).each do |entry|
        Array(entry["items"]).each do |kind, text|
          by_kind[kind.to_s] << text if Lexeme.kinds.key?(kind.to_s)
        end
      end

      by_kind.each_with_object({}) do |(kind, texts), index|
        Lexeme.where(kind:, text: texts.uniq).pluck(:text, :id).each { |text, id| index[[kind, text]] = id }
      end
    end
  end
end
