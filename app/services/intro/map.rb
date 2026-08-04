# frozen_string_literal: true

module Intro
  class Map
    PATH = Rails.root.join("config/intro_map.yml")

    Step = Data.define(:id, :chapter, :path, :target, :advance, :lands_on, :interactive, :version) do
      def waits_for_click? = advance == "click"

      def interactive? = waits_for_click? || interactive == true

      def anchored? = target.present?

      def scope = chapter || "essential"

      def i18n_key = chapter ? "intro.chapters.#{chapter}.steps.#{id}" : "intro.steps.#{id}"
    end

    Chapter = Data.define(:id, :icon, :steps) do
      def length = steps.length

      def i18n_key = "intro.chapters.#{id}"
    end

    class << self
      def version = data["version"].to_i

      def essential = load!.first

      def chapters = load!.last

      def chapter(id) = chapters.find { |entry| entry.id == id.to_s }

      def all_steps = essential + chapters.flat_map(&:steps)

      def newer_than(version)
        all_steps.select { |step| step.version > version.to_i }
      end

      def reset!
        @load = nil
        @data = nil
      end

      private

      def data
        @data ||= YAML.load_file(PATH)
      end

      def load!
        @load ||= [
          Array(data["essential"]).map { |row| build(row, nil) },
          Array(data["chapters"]).map do |row|
            Chapter.new(
              id: row.fetch("id"),
              icon: row["icon"],
              steps: Array(row["steps"]).map { |step| build(step, row.fetch("id")) }
            )
          end
        ]
      end

      def build(row, chapter)
        Step.new(
          id: row.fetch("id"),
          chapter: chapter,
          path: row["path"],
          target: row["target"],
          advance: row["advance"],
          lands_on: row["lands_on"],
          interactive: row["interactive"],
          version: row.fetch("version", 1).to_i
        )
      end
    end
  end
end
