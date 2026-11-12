# frozen_string_literal: true

require "json"

module Pronunciation
  module Acoustic
    module Syllables
      def self.default_path
        File.join(TemplateStore.instance.root, "inventory.json")
      end

      NO_TONES = [].freeze

      @inventory = {}.freeze
      @by_syllable = {}.freeze
      @zhuyin = {}.freeze
      @loaded = false

      class << self
        def zhuyin
          load! unless @loaded
          @zhuyin
        end

        OFF_PINYIN = {"eh" => "ㄝ", "r" => "ㄦ"}.freeze

        def spells_its_own_key?(key, stored)
          return false if stored.blank?

          spelled = spell(key)
          return true if spelled.nil?

          stored.delete(Parts::TONE_CHARS) == spelled.delete(Parts::TONE_CHARS)
        end

        def spell(key)
          parsed = parse_key(key)
          return nil if parsed.nil?

          syllable, tone = parsed
          base = OFF_PINYIN[syllable] || compose(syllable)
          return nil if base.blank?

          Huayu::Zhuyin.apply_tone(base, tone)
        end

        def compose(syllable)
          parts = Huayu::Zhuyin.syllabify(syllable.tr("v", "ü"))
          return nil if parts.blank?

          parts.map { |part| part["zhuyin"].to_s.delete(Parts::TONE_CHARS) }.join.presence
        end

        def load!(path = Syllables.default_path)
          present = File.exist?(path)
          inventory = present ? JSON.parse(File.read(path))["keys"] : {}
          by_syllable = {}
          zhuyin = {}
          inventory.each do |key, meta|
            (by_syllable[meta["syllable"]] ||= []) << meta["tone"]
            zhuyin[key] = spells_its_own_key?(key, meta["zhuyin"]) ? meta["zhuyin"] : spell(key)
          end

          by_syllable.each_value { |tones| tones.sort!.freeze }
          speller = method(:spell)
          @structure_cache = {}
          @neighbor_cache = {}
          @inventory = inventory.freeze
          @by_syllable = by_syllable.freeze
          @zhuyin = Hash.new { |_table, key| speller.call(key) }.merge!(zhuyin).freeze
          @loaded = present
          inventory
        end

        def described?(key) = spells_its_own_key?(key, inventory.dig(key, "zhuyin"))

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
          @by_syllable.fetch(syllable, NO_TONES)
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
          @neighbor_cache ||= {}
          keys = []

          tones_for(syllable).each { |t| keys << key_for(syllable, t) unless t == tone }

          nb = (@neighbor_cache[syllable] ||= Phonology.neighbors(syllable, all_syllables))
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
