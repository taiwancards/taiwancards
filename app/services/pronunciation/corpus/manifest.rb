# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class Manifest
      DIRS = {
        "corpus_tw" => "manifest.json",
        "corpus_cns" => "manifest.json",
        "corpus_cv" => CommonVoiceTokens::FILE
      }.freeze
      RELATIVE = %r{\Adata/([^/]+)/}

      def initialize(dirs: DIRS, base: nil)
        home = base || TemplateStore.instance.root
        @files = dirs
        @roots = dirs.keys.to_h { |dir| [dir, File.join(home, dir)] }
      end

      attr_reader :roots

      def paths = @roots.to_h { |dir, root| [dir, File.join(root, @files.fetch(dir))] }

      def exist? = manifests.any?

      def sources = manifests.values.map { |data| data.fetch("sources", {}) }.reduce({}, :merge)

      def keys = manifests.values.flat_map { |data| data.fetch("tokens", {}).keys }.uniq

      def resolve(relative)
        dir = relative[RELATIVE, 1]
        File.join(@roots.fetch(dir) { @roots.values.first }, relative.sub(RELATIVE, ""))
      end

      TONE = /[1-5]\z/

      def by_file(only: nil)
        grouped = Hash.new { |hash, file| hash[file] = [] }

        manifests.each_value do |data|
          data.fetch("tokens", {}).each do |key, tokens|
            tokens.each do |token|
              settled = settle(key, token)
              next if only && !only.include?(settled)

              grouped[token["path"]] << token.merge("_key" => settled)
            end
          end
        end

        grouped.select { |relative, _| File.exist?(resolve(relative)) }
      end

      def settle(key, token)
        derived = spelled(token)
        return key if derived.nil? || derived.sub(TONE, "") == key.to_s.sub(TONE, "")

        "#{derived.sub(TONE, "")}#{key.to_s[TONE] || derived[TONE]}"
      end

      def spelled(token)
        pinyin = token["pinyin"].to_s
        return nil if pinyin.empty?

        parts = Huayu::Zhuyin.syllabify(pinyin)
        part = parts && parts[token["index"].to_i]
        return nil if part.nil?

        "#{Huayu::ReadingForms.plain_pinyin(part["pinyin"])}#{Huayu::Zhuyin.tone(part["pinyin"])}"
      end

      private

      def manifests
        @manifests ||= paths.filter_map { |dir, path| [dir, JSON.parse(File.read(path))] if File.exist?(path) }.to_h
      end
    end
  end
end
