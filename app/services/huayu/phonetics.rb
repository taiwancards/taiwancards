# frozen_string_literal: true

module Huayu
  class Phonetics
    DATA = JsonData.new("huayu/phonetics.json")

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

      def data = DATA.value

      def reset! = DATA.reset!
    end
  end
end
