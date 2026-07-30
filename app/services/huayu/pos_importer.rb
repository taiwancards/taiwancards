# frozen_string_literal: true

module Huayu
  class PosImporter
    PATH = AppData.path("huayu/parts_of_speech.json")
    KINDS = %i[word character].freeze

    def initialize(path: PATH)
      @table = File.exist?(path) ? JSON.parse(File.read(path)) : {}
    end

    def call
      filled = {tocfl: 0, moe: 0}
      return filled if @table.empty?

      Lexeme.where(kind: KINDS).where(text: @table.keys).find_each(batch_size: 500) do |lexeme|
        entry = @table[lexeme.text]
        next if entry.blank?

        data = lexeme.data.merge(
          {"pos" => entry["tocfl"].presence, "pos_moe" => entry["moe"].presence}.compact
        )
        filled[:tocfl] += 1 if entry["tocfl"].present?
        filled[:moe] += 1 if entry["moe"].present?
        lexeme.update_column(:data, data) if data != lexeme.data
      end

      filled
    end
  end
end
