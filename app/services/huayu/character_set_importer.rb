# frozen_string_literal: true

module Huayu
  class CharacterSetImporter
    TIERS = [
      {file: "huayu/moe4808.json", set: "常用", source: "MOE 常用字"},
      {file: "huayu/moe_next6343.json", set: "次常用", source: "MOE 次常用字"},
      {file: "huayu/moe_rare.json", set: "罕用", source: "MOE 罕用字"}
    ].freeze

    def initialize(enrich: true)
      @enrich = enrich
    end

    def call
      existing = Lexeme
        .where(kind: :character)
        .pluck(:text, :id)
        .to_h
      counts = Hash.new(0)
      position = 0

      TIERS.each do |tier|
        characters = JSON.parse(AppData.path(tier[:file]).read)
        characters.each do |text|
          position += 1
          if existing.key?(text)
            update(existing.fetch(text), text, position, tier, counts)
          else
            create(text, position, tier, counts)
          end
        end
      end

      counts[:enriched] = Huayu::CharacterEnricher.new.call if @enrich
      counts
    end

    private

    def create(text, position, tier, counts)
      Lexeme.create!(
        kind: :character,
        text: text,
        sources: [tier[:source]],
        data: {"moe_index" => position, "char_set" => tier[:set]}
      )
      counts[:"created_#{tier[:set]}"] += 1
    end

    def update(id, text, position, tier, counts)
      lexeme = Lexeme.find(id)
      lexeme.data = lexeme.data.merge("moe_index" => position, "char_set" => tier[:set])
      lexeme.add_source(tier[:source])
      return unless lexeme.changed?

      lexeme.save!
      counts[:"updated_#{tier[:set]}"] += 1
    end
  end
end
