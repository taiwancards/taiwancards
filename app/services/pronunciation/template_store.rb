# frozen_string_literal: true

module Pronunciation
  class TemplateStore
    DEFAULT_PATH = "/var/data/pronunciation"
    CITATION = "taiwan"
    WORD_INITIAL = "taiwan_wi"
    WORD_MEDIAL = "taiwan_wm"

    class << self
      def instance
        store = (@instance ||= new(root_path))
        return store if store.available?

        @instance = new(root_path)
      end

      def reset!
        @instance = nil
      end

      def root_path
        explicit = ENV["PRONUNCIATION_DATA_PATH"].presence
        return explicit if explicit

        candidates = [DEFAULT_PATH, Rails.root.join("data/pronunciation").to_s]
        candidates.find { |path| File.directory?(File.join(path, "templates", CITATION)) } || DEFAULT_PATH
      end
    end

    def initialize(root)
      @root = root
      @cache = {}
      @mutex = Mutex.new
    end

    attr_reader :root

    def available?
      File.directory?(File.join(@root, "templates", CITATION))
    end

    def template(key, norm = CITATION)
      @mutex.synchronize do
        @cache.fetch([key, norm]) do
          path = File.join(@root, "templates", norm, "#{key}.json")
          next nil unless File.exist?(path)

          @cache[[key, norm]] = JSON.parse(File.read(path))
        end
      end
    end

    def norm_for(position:, total:)
      return CITATION if total <= 1

      position.zero? ? WORD_INITIAL : WORD_MEDIAL
    end

    def thresholds
      @thresholds || read_once("thresholds.json") { |data| @thresholds = data }
    end

    def index
      @index || read_once(File.join("templates", "index.json")) { |data| @index = data }
    end

    private

    def read_once(relative)
      path = File.join(@root, relative)
      return {} unless File.exist?(path)

      yield(JSON.parse(File.read(path)))
    end
  end
end
