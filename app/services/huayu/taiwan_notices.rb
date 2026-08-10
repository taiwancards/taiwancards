# frozen_string_literal: true

module Huayu
  class TaiwanNotices
    PATH = AppData.path("huayu/taiwan_notices.json")
    STYLES = %w[document minutes steps].freeze

    Item = Data.define(:mark, :head, :zh, :indent, :names) do
      def name(locale) = names[locale.to_s].presence || names["en"]

      def indent? = indent
    end

    Notice = Data.define(:id, :kind, :category, :position, :style, :date, :doc, :issuer, :closing, :items, :names) do
      def zh = names["zh"]

      def name(locale) = names[locale.to_s].presence || names["en"]

      def issuer_name(locale) = issuer[locale.to_s].presence || issuer["en"]

      def closing_name(locale) = closing && (closing[locale.to_s].presence || closing["en"])

      def steps? = style == "steps"

      def sentences = items.map(&:zh)
    end

    class << self
      def all = payload[:notices]

      def find(id) = payload[:by_id][id.to_s]

      def categories = all.map(&:category).uniq

      def in_category(category) = all.select { |notice| notice.category == category.to_s }

      def sentences = all.flat_map(&:sentences).uniq

      def reset! = @payload = nil

      private

      def payload
        @payload ||= begin
          notices = read.fetch("notices", []).map { |raw| build(raw) }.sort_by(&:position)
          {notices: notices, by_id: notices.index_by(&:id)}
        end
      end

      def read
        PATH.exist? ? JSON.parse(PATH.read) : {"notices" => []}
      end

      def build(raw)
        Notice.new(
          id: raw.fetch("id"),
          kind: raw.fetch("kind"),
          category: raw.fetch("category"),
          position: raw.fetch("position", 0).to_i,
          style: raw.fetch("style", "document").presence_in(STYLES) || "document",
          date: raw["date"].presence,
          doc: raw["doc"].presence,
          issuer: raw.fetch("issuer", {}),
          closing: raw["closing"].presence,
          items: raw.fetch("items", []).map { |item| item(item) },
          names: raw.fetch("title", {})
        )
      end

      def item(raw)
        Item.new(
          mark: raw["mark"].to_s,
          head: raw["head"].presence,
          zh: raw.fetch("zh"),
          indent: raw.fetch("indent", false),
          names: raw.except("mark", "head", "zh", "indent")
        )
      end
    end
  end
end
