# frozen_string_literal: true

module Huayu
  class RadicalImporter
    PATH = AppData.path("huayu/kangxi_radicals.json")
    SOURCE = "Kangxi 214"

    VARIANTS = {
      "氵" => "水",
      "氺" => "水",
      "扌" => "手",
      "亻" => "人",
      "糹" => "糸",
      "⺼" => "肉",
      "忄" => "心",
      "⺗" => "心",
      "釒" => "金",
      "阝" => "阜",
      "⺮" => "竹",
      "王" => "玉",
      "刂" => "刀",
      "刁" => "刀",
      "衤" => "衣",
      "飠" => "食",
      "攵" => "攴",
      "礻" => "示",
      "灬" => "火",
      "炏" => "火",
      "罒" => "网",
      "⺳" => "网",
      "乚" => "乙",
      "巳" => "己",
      "㔾" => "卩",
      "爫" => "爪",
      "巛" => "川",
      "民" => "氏",
      "耂" => "老",
      "虎" => "虍",
      "麦" => "麥",
      "羋" => "羊",
      "毋" => "母",
      "孑" => "子",
      "兀" => "儿",
      "彑" => "彐",
      "丷" => "八",
      "⺌" => "小",
      "⺊" => "卜",
      "旡" => "无",
      "肀" => "聿",
      "⺀" => "冫",
      "犬" => "犭",
      "艸" => "艹",
      "覀" => "西",
      "襾" => "西",
      "辵" => "辶"
    }.freeze

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      radicals = JSON.parse(@path.read)
      index = upsert_radicals(radicals)
      verify_variant_targets!(index)
      linked, unmatched = link_characters(index)
      {radicals: index.size, linked:, unmatched:}
    end

    private

    def upsert_radicals(radicals)
      radicals.each_with_object({}) do |entry, index|
        lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[:radical], text: entry["radical"])
        lexeme.readings = {"pinyin" => entry["pinyin"], "zhuyin" => entry["zhuyin"]}.compact_blank
        lexeme.meanings = lexeme.meanings.merge("en" => entry["meaning_en"]).compact_blank
        lexeme.data = lexeme.data.merge("number" => entry["number"], "strokes" => entry["strokes"])
        lexeme.add_source(SOURCE)
        lexeme.save! if lexeme.changed?
        index[entry["radical"]] = lexeme
      end
    end

    def verify_variant_targets!(index)
      missing = VARIANTS.values.uniq.reject { |target| index.key?(target) }
      raise "Variant targets not in canonical set: #{missing.inspect}" if missing.any?
    end

    def link_characters(index)
      linked = 0
      unmatched = Hash.new(0)
      Lexeme.where(kind: :character).find_each do |char|
        form = char.data["radical"]
        next if form.blank?

        canonical = VARIANTS[form] || form
        radical = index[canonical]
        if radical.nil?
          unmatched[form] += 1
          next
        end

        char.data = char.data.merge("radical_number" => radical.data["number"], "radical_canonical" => canonical)
        char.save! if char.changed?
        linked += 1
      end

      [linked, unmatched.sort_by { |_, count| -count }.first(10).to_h]
    end
  end
end
