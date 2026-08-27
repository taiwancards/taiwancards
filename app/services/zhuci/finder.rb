# frozen_string_literal: true

module Zhuci
  class Finder
    def self.call(text) = new.call(text)

    def call(text)
      text = text.to_s
      return nil if text.blank?

      Lexeme.find_by(kind: :particle, text:) || by_variant(text)
    end

    private

    def by_variant(text)
      Lexeme.where(kind: :particle).where("data -> 'variants' @> ?", [{"text" => text}].to_json).first
    end
  end
end
