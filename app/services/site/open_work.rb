# frozen_string_literal: true

module Site
  module OpenWork
    Entry = Data.define(:key, :name, :url, :license, :mirror, :mirror_label) do
      def initialize(key:, name:, url:, license: nil, mirror: nil, mirror_label: nil)
        super
      end
    end

    Group = Data.define(:key, :entries)

    GITHUB = "https://github.com"
    RUBYGEMS = "https://rubygems.org/gems"
    HUGGINGFACE = "https://huggingface.co/datasets"

    GROUPS = [
      Group.new(
        key: :app,
        entries: [
          Entry.new(key: :taiwancards, name: "taiwancards/taiwancards", url: "#{GITHUB}/taiwancards/taiwancards"),
          Entry.new(key: :corpora, name: "taiwancards/corpora", url: "#{GITHUB}/taiwancards/corpora")
        ]
      ),
      Group.new(
        key: :pipeline,
        entries: [
          Entry.new(
            key: :twpipeline,
            name: "taiwan-corpora/twpipeline",
            url: "#{GITHUB}/taiwan-corpora/twpipeline",
            license: "MIT"
          ),
          Entry.new(
            key: :twfilter,
            name: "taiwan-corpora/twfilter",
            url: "#{GITHUB}/taiwan-corpora/twfilter",
            license: "MIT"
          )
        ]
      ),
      Group.new(
        key: :gems,
        entries: [
          Entry.new(
            key: :dsprb,
            name: "dsprb",
            url: "#{GITHUB}/taiwancards/dsprb",
            license: "WTFPL",
            mirror: "#{RUBYGEMS}/dsprb",
            mirror_label: "RubyGems"
          ),
          Entry.new(
            key: :dtwrb,
            name: "dtwrb",
            url: "#{GITHUB}/taiwancards/dtwrb",
            license: "WTFPL",
            mirror: "#{RUBYGEMS}/dtwrb",
            mirror_label: "RubyGems"
          )
        ]
      ),
      Group.new(
        key: :datasets,
        entries: [
          Entry.new(
            key: :twngrams,
            name: "taiwan-corpora/twngrams",
            url: "#{HUGGINGFACE}/taiwan-corpora/twngrams",
            license: "CC0 1.0"
          ),
          Entry.new(
            key: :twsyllables,
            name: "taiwan-corpora/twsyllables",
            url: "#{HUGGINGFACE}/taiwan-corpora/twsyllables",
            license: "CC BY 4.0"
          ),
          Entry.new(
            key: :twfilter_tables,
            name: "taiwan-corpora/twfilter-tables",
            url: "#{HUGGINGFACE}/taiwan-corpora/twfilter-tables"
          )
        ]
      )
    ].freeze
  end
end
