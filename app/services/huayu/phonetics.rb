# frozen_string_literal: true

module Huayu
  class Phonetics
    PATH = AppData.path("huayu/phonetics.json")

    class << self
      def initials
        data["initials"]
      end

      def finals
        data["finals"]
      end

      def rimes
        data["rimes"] || []
      end

      def data
        @data ||= JSON.parse(PATH.read)
      end

      def reset!
        @data = nil
      end
    end
  end
end
