# frozen_string_literal: true

module Huayu
  class TaiwanNotices
    PATH = AppData.path("huayu/taiwan_notices.json")
    STYLES = %w[document minutes steps form].freeze
    SITUATIONS = %w[health work money home building school transport residence shops].freeze

    Item = Data.define(:mark, :head, :zh, :indent, :names, :notes) do
      def name(locale) = Locales.pick(names, locale)

      def note(locale) = Locales.pick(notes, locale)

      def indent? = indent
    end

    Field = Data.define(:zh, :value, :key, :heading, :names, :notes) do
      def name(locale) = Locales.pick(names, locale)

      def note(locale) = Locales.pick(notes, locale)

      def key? = key

      def heading? = heading

      def texts = [zh, value].compact
    end

    Notice = Data.define(
      :id,
      :kind,
      :category,
      :situation,
      :position,
      :style,
      :draft,
      :date,
      :doc,
      :issuer,
      :closing,
      :about,
      :items,
      :fields,
      :names
    ) do
      def zh = names["zh"]

      def name(locale) = Locales.pick(names, locale)

      def issuer_name(locale) = Locales.pick(issuer, locale)

      def closing_name(locale) = closing && Locales.pick(closing, locale)

      def about_text(locale) = Locales.pick(about, locale)

      def steps? = style == "steps"

      def form? = style == "form"

      def draft? = draft

      def sentences = items.map(&:zh)

      def texts = [zh, (kind if form?), *sentences, *fields.flat_map(&:texts)].compact
    end

    class << self
      def all = payload[:notices]

      def find(id) = payload[:by_id][id.to_s]

      def drafts = payload[:drafts]

      def categories = all.map(&:category).uniq

      def in_category(category) = all.select { |notice| notice.category == category.to_s }

      def situations = SITUATIONS & all.map(&:situation)

      def in_situation(situation) = all.select { |notice| notice.situation == situation.to_s }

      def by_situation = situations.index_with { |situation| in_situation(situation) }

      def sentences = all.flat_map(&:sentences).uniq

      def reset! = @payload = nil

      private

      def payload
        @payload ||= begin
          drafts, notices = read.fetch("notices", []).map { |raw| build(raw) }.sort_by(&:position).partition(&:draft?)
          {notices: notices, by_id: notices.index_by(&:id), drafts: drafts}
        end
      end

      def read
        PATH.exist? ? JSON.parse(PATH.read) : {"notices" => []}
      end

      def build(raw)
        situation = raw.fetch("situation")
        Notice.new(
          id: raw.fetch("id"),
          kind: raw.fetch("kind"),
          category: raw.fetch("category", situation),
          situation: situation,
          position: raw.fetch("position", 0).to_i,
          style: raw.fetch("style", "document").presence_in(STYLES) || "document",
          draft: raw.fetch("draft", false),
          date: raw["date"].presence,
          doc: raw["doc"].presence,
          issuer: raw.fetch("issuer", {}),
          closing: raw["closing"].presence,
          about: raw.fetch("about", {}),
          items: raw.fetch("items", []).map { |item| item(item) },
          fields: raw.fetch("fields", []).map { |field| field(field) },
          names: raw.fetch("title", {})
        )
      end

      def item(raw)
        Item.new(
          mark: raw["mark"].to_s,
          head: raw["head"].presence,
          zh: raw.fetch("zh"),
          indent: raw.fetch("indent", false),
          names: raw.except("mark", "head", "zh", "indent", "note"),
          notes: raw.fetch("note", {})
        )
      end

      def field(raw)
        label = raw["heading"] || raw.fetch("label")
        Field.new(
          zh: label.fetch("zh"),
          value: raw["value"].presence,
          key: raw.fetch("key", false),
          heading: raw.key?("heading"),
          names: label.except("zh"),
          notes: raw.fetch("note", {})
        )
      end
    end
  end
end
