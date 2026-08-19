# frozen_string_literal: true

module Intro
  class Highlights
    KEY = "intro/highlights/v1"
    TTL = 12.hours

    Block = Data.define(:id, :path, :figures)

    class << self
      def fetch
        Rails.cache.fetch(KEY, expires_in: TTL) { compute }
      end

      def reset! = Rails.cache.delete(KEY)

      def compute
        counts = Site::Counts.compute

        [
          Block.new(id: "course", path: "/course", figures: {lessons: lessons, stages: stages}),
          Block.new(id: "dictionary", path: "/dict", figures: counts.slice(:characters, :words, :sentences)),
          Block.new(id: "search", path: "/search", figures: {}),
          Block.new(id: "decks", path: "/desks", figures: {}),
          Block.new(id: "grammar", path: "/grammar", figures: {lessons: grammar}),
          Block.new(id: "trainers", path: "/pronunciation", figures: {}),
          Block.new(id: "taiwan", path: "/everyday", figures: {}),
          Block.new(id: "reader", path: "/reader", figures: {})
        ]
      end

      private

      def lessons = Huayu::CourseLessons.available? ? Huayu::CourseLessons.lessons.size : 0

      def stages = Huayu::CourseLessons.available? ? Huayu::CourseLessons.stages.size : 0

      def grammar = Lexeme.where(kind: :grammar).count
    end
  end
end
