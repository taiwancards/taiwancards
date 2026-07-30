# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    module Syllables
      def self.default_path
        File.join(TemplateStore.instance.root, "inventory.json")
      end

      @inventory = nil
      @by_syllable = nil
      @zhuyin = {}
      @loaded = false

      class << self
        def zhuyin
          load! unless @loaded
          @zhuyin
        end

        def load!(path = Syllables.default_path)
          @loaded = File.exist?(path)
          @inventory = @loaded ? JSON.parse(File.read(path))["keys"] : {}
          @by_syllable = Hash.new { |h, k| h[k] = [] }
          @zhuyin = {}
          @inventory.each do |key, meta|
            @by_syllable[meta["syllable"]] << meta["tone"]
            @zhuyin[key] = meta["zhuyin"]
          end

          @by_syllable.each_value(&:sort!)
          @structure_cache = {}
          @neighbour_cache = {}
          @inventory
        end

        def inventory
          load! unless @loaded
          @inventory
        end

        def all_keys
          inventory.keys
        end

        def all_syllables
          load! unless @loaded
          @by_syllable.keys
        end

        def tones_for(syllable)
          load! unless @loaded
          @by_syllable[syllable] || []
        end

        def key_for(syllable, tone) = "#{syllable}#{tone}"

        def parse_key(key)
          m = key.match(/\A([a-zü]+)(\d)\z/)
          m ? [m[1], m[2].to_i] : nil
        end

        def entry(syllable, tone)
          inventory[key_for(syllable, tone)]
        end

        def structure(syllable)
          @structure_cache ||= {}
          @structure_cache[syllable] ||= Phonology.analyze(syllable)
        end

        def confusion_set(syllable, tone)
          load! unless @loaded
          @neighbour_cache ||= {}
          keys = []

          tones_for(syllable).each { |t| keys << key_for(syllable, t) unless t == tone }

          nb = (@neighbour_cache[syllable] ||= Phonology.neighbors(syllable, all_syllables))
          nb.each do |other|
            other_tones = tones_for(other)
            if other_tones.include?(tone)
              keys << key_for(other, tone)
            else
              other_tones.each { |t| keys << key_for(other, t) }
            end
          end

          keys.uniq.select { |k| inventory.key?(k) }
        end
      end
    end
  end
end
