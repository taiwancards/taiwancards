# frozen_string_literal: true

module Graded
  class Library
    DIR = "huayu/reader"

    Note = Data.define(:zh, :names) do
      def name(locale) = names[locale.to_s].presence || names["en"]
    end

    Line = Data.define(:zh, :names) do
      def name(locale) = names[locale.to_s].presence || names["en"]
    end

    Text = Data.define(:id, :tier, :topic, :titles, :lines, :notes) do
      def title(locale) = titles[locale.to_s].presence || titles["en"]

      def zh = titles["zh"]

      def body = lines.map(&:zh).join

      def sentences = lines.size

      def length = body.length

      def note_for(word) = notes.find { |note| note.zh == word }
    end

    class << self
      def tiers = Levels.ids.select { |id| texts(id).any? }

      def texts(tier) = payload[tier.to_s] || []

      def find(tier, id) = texts(tier).find { |text| text.id == id.to_s }

      def all = Levels.ids.flat_map { |id| texts(id) }

      def reset! = @payload = nil

      private

      def payload
        @payload ||= Levels.ids.index_with { |id| read(id) }
      end

      def read(tier)
        path = AppData.path("#{DIR}/#{tier}.json")
        return [] unless path.exist?

        JSON.parse(path.read).fetch("texts", []).map { |raw| build(tier, raw) }
      end

      def build(tier, raw)
        Text.new(
          id: raw.fetch("id"),
          tier: tier,
          topic: raw["topic"].to_s,
          titles: raw.fetch("title", {}),
          lines: raw.fetch("lines", []).map { |line| Line.new(zh: line.fetch("zh"), names: line.slice("en", "ru")) },
          notes: raw.fetch("notes", []).map { |note| Note.new(zh: note.fetch("zh"), names: note.slice("en", "ru")) }
        )
      end
    end
  end
end
