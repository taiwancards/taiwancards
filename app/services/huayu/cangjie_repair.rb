# frozen_string_literal: true

module Huayu
  class CangjieRepair
    Result = Data.define(:examined, :repaired) do
      def changed? = repaired.positive?

      def to_s = "cangjie codes restored to the canonical fifth-generation form: #{repaired} of #{examined}"
    end

    def call
      rows = pending
      Lexeme.where(id: rows.keys).each do |lexeme|
        lexeme.update_column(:data, lexeme.data.merge("cangjie" => rows.fetch(lexeme.id)))
      end

      Result.new(examined: stored.length, repaired: rows.length)
    end

    def drift? = pending.any?

    private

    def stored
      @stored ||= Lexeme
        .where(kind: :character, text: Cangjie::CANONICAL.keys)
        .pluck(:id, :text, Arel.sql("data->>'cangjie'"))
    end

    def pending
      @pending ||= stored
        .filter_map do |id, text, code|
          canonical = Cangjie::CANONICAL.fetch(text)
          [id, canonical] if code != canonical
        end
        .to_h
    end
  end
end
