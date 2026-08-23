# frozen_string_literal: true

module Pronunciation
  class TemplateStore
    DEFAULT_PATH = "/var/data/pronunciation"
    MAX_CACHED_TEMPLATES = Integer(ENV.fetch("PRONUNCIATION_TEMPLATE_CACHE", 256))
    CITATION = "taiwan"
    WORD = "taiwan_word"
    WORD_INITIAL = "taiwan_wi"
    WORD_MEDIAL = "taiwan_wm"
    WORD_FINAL = "taiwan_wf"

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
        cache_key = [key, norm]
        cached = @cache.delete(cache_key)
        unless cached.nil?
          @cache[cache_key] = cached
          return cached
        end

        path = File.join(@root, "templates", norm, "#{key}.json")
        return nil unless File.exist?(path)

        @cache.shift if @cache.size >= MAX_CACHED_TEMPLATES
        @cache[cache_key] = JSON.parse(File.read(path))
      end
    end

    def max_cached = MAX_CACHED_TEMPLATES

    def norm_for(position:, total:)
      total <= 1 ? CITATION : WORD
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
