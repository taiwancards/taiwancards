# frozen_string_literal: true

module Offline
  module Sections
    Section = Data.define(:id, :group, :level) do
      def levelled? = level.present?

      def title(locale) = I18n.t("offline.packs.#{id}", locale: locale, default: level.to_s)

      def summary(locale) = I18n.t("offline.summaries.#{group}", locale: locale, default: "")
    end

    CORE = "core"

    GROUPS = %w[core texts reference dictionary].freeze

    FIXED = [
      %w[core core],
      %w[grammar texts],
      %w[graded texts],
      %w[cangjie texts],
      %w[taiwan reference],
      %w[reference reference],
      %w[chengyu dictionary]
    ].freeze

    module_function

    def all
      FIXED.map { |id, group| Section.new(id: id, group: group, level: nil) } + levels
    end

    def levels
      SentenceProfile::TOCFL_LEVELS.map do |level|
        Section.new(id: "tocfl-#{level.downcase}", group: "dictionary", level: level)
      end
    end

    def find(id) = all.find { |section| section.id == id }

    def ids = all.map(&:id)
  end
end
