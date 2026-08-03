# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class Manifest
      DIRS = %w[corpus_tw corpus_cns].freeze
      RELATIVE = %r{\Adata/([^/]+)/}

      def initialize(dirs: DIRS, base: nil)
        home = base || TemplateStore.instance.root
        @roots = dirs.to_h { |dir| [dir, File.join(home, dir)] }
      end

      attr_reader :roots

      def paths = @roots.transform_values { |root| File.join(root, "manifest.json") }

      def exist? = manifests.any?

      def sources = manifests.values.map { |data| data.fetch("sources", {}) }.reduce({}, :merge)

      def keys = manifests.values.flat_map { |data| data.fetch("tokens", {}).keys }.uniq

      def resolve(relative)
        dir = relative[RELATIVE, 1]
        File.join(@roots.fetch(dir) { @roots.values.first }, relative.sub(RELATIVE, ""))
      end

      def by_file(only: nil)
        grouped = Hash.new { |hash, file| hash[file] = [] }

        manifests.each_value do |data|
          data.fetch("tokens", {}).each do |key, tokens|
            next if only && !only.include?(key)

            tokens.each { |token| grouped[token["path"]] << token.merge("_key" => key) }
          end
        end

        grouped.select { |relative, _| File.exist?(resolve(relative)) }
      end

      private

      def manifests
        @manifests ||= paths.filter_map { |dir, path| [dir, JSON.parse(File.read(path))] if File.exist?(path) }.to_h
      end
    end
  end
end
