# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    module VotNorms
      PATH = "vot_norms.json"
      KAPPA = 6.0
      MIN_POOL = 20

      module_function

      def path = File.join(TemplateStore.instance.root, PATH)

      def data
        @data ||= File.exist?(path) ? JSON.parse(File.read(path)) : {}
      end

      def reset! = @data = nil

      def build!(source: Tokens::TAIWAN)
        pooled = Hash.new { |hash, initial| hash[initial] = [] }

        FanOut.map(Tokens.available(source)) { |chunk| gather(chunk, source) }.each do |partial|
          partial.each { |initial, values| pooled[initial].concat(values) }
        end

        @data = pooled
          .select { |_, values| values.length >= MIN_POOL }
          .transform_values { |values| Acoustic::Templates.stat(values) }
          .compact

        File.write(path, JSON.pretty_generate(@data))
        @data
      end

      def gather(keys, source)
        out = Hash.new { |hash, initial| hash[initial] = [] }

        keys.each do |key|
          initial = initial_of(key)
          next if initial.nil? || initial.empty?

          Tokens.each(key, source) do |row|
            out[initial] << row["vot_ms"] if row["vot_reliable"] && row["vot_ms"]
          end
        end

        out
      end

      def initial_of(key)
        parsed = Acoustic::Syllables.parse_key(key)
        parsed && Acoustic::Syllables.structure(parsed[0])[:initial].to_s
      end

      def for_rows(key, rows)
        initial = initial_of(key)
        return :own if initial.nil? || initial.empty?

        blend(initial, Acoustic::Templates.stat(rows.select { |r| r["vot_reliable"] }.map { |r| r["vot_ms"] }))
      end

      def blend(initial, own)
        pool = data[initial.to_s]
        return own if pool.nil?
        return pool.merge("n_key" => 0, "pooled" => true) if own.nil?

        n = own["n"].to_f
        weight = n / (n + KAPPA)

        own.merge(
          "median" => (weight * own["median"]) + ((1.0 - weight) * pool["median"]),
          "mad" => [own["mad"].to_f, pool["mad"].to_f].max,
          "sd" => [own["sd"].to_f, pool["sd"].to_f].max,
          "n_key" => own["n"],
          "n_pool" => pool["n"],
          "pooled" => weight < 1.0
        )
      end
    end
  end
end
