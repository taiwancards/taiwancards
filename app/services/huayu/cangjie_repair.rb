# frozen_string_literal: true

module Huayu
  class CangjieRepair
    Result = Data.define(:examined, :repaired) do
      def changed? = repaired.positive?

      def to_s = "cangjie codes superseded by the fifth generation: #{repaired} of #{examined}"
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
        .where(kind: :character, text: Cangjie::SUPERSEDED.keys)
        .pluck(:id, :text, Arel.sql("data->>'cangjie'"))
    end

    def pending
      @pending ||= stored
        .filter_map do |id, text, code|
          fifth = Cangjie::SUPERSEDED.fetch(text)
          [id, fifth] if code != fifth
        end
        .to_h
    end
  end
end
