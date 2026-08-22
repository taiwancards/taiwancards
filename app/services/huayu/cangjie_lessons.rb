# frozen_string_literal: true

module Huayu
  class CangjieLessons
    extend LessonData

    DATA = JsonData.new("huayu/cangjie_lessons.json", default: {}, watch: true)

    Lesson = Data.define(:id, :slug, :stage, :key, :letter, :title, :lede, :blocks, :bank, :drills, :index) do
      def to_param = slug
      def letter? = key.present?

      def title_for(locale) = CangjieLessons.text(title, locale)
      def lede_for(locale) = CangjieLessons.text(lede, locale)
    end

    Group = Data.define(:id, :zh, :keys, :ru, :en) do
      def name(locale) = (locale.to_s == "ru" ? ru : en).presence || en
    end

    class << self
      def all = lessons
      def stages = payload[:stages]
      def groups = payload[:groups]
      def core = payload[:core]
      def exam = payload[:exam]
      def by_stage = payload[:by_stage]
      def for_key(key) = payload[:by_key][key.to_s]

      def stage_name(stage, locale)
        text(stages.find { |item| item["id"] == stage.to_s }, locale)
      end

      def text(row, locale = I18n.locale) = pick(row, locale)

      private

      def build(raw)
        rows = Array(raw["lessons"]).map { |row| build_lesson(row) }.freeze
        {
          stages: Array(raw["stages"]).freeze,
          groups: Array(raw["groups"])
            .map { |row| Group.new(**row.symbolize_keys.slice(:id, :zh, :keys, :ru, :en)) }
            .freeze,
          core: Array(raw["core"]).freeze,
          exam: Array(raw["exam"]).freeze,
          lessons: rows,
          by_slug: slug_index(rows).merge(rows.index_by { |lesson| lesson.id.to_s }).freeze,
          by_key: rows.select(&:letter?).index_by(&:key).freeze,
          by_stage: rows.group_by(&:stage).freeze
        }
      end

      def build_lesson(row)
        Lesson.new(
          id: row["id"],
          slug: row["slug"],
          stage: row["stage"],
          key: row["key"],
          letter: row["letter"],
          title: row["title"] || {},
          lede: row["lede"] || {},
          blocks: Array(row["blocks"]).freeze,
          bank: Array(row["bank"]).freeze,
          drills: Array(row["drills"]).freeze,
          index: Array(row["index"]).freeze
        )
      end
    end
  end
end
