# frozen_string_literal: true

module Huayu
  module ErhuaSpellings
    BASES = {
      "畫兒" => "畫",
      "花兒" => "花",
      "事兒" => "事",
      "邊兒" => "邊",
      "有一點兒" => "有一點",
      "有空兒" => "有空",
      "聊天兒" => "聊天",
      "相片兒" => "相片",
      "一半兒" => "一半",
      "一下子兒" => "一下子",
      "茶館兒" => "茶館",
      "船兒" => "船",
      "冰塊兒" => "冰塊",
      "味兒" => "味",
      "差點兒" => "差點",
      "差一點兒" => "差一點",
      "個兒" => "個子",
      "好好兒" => "好好",
      "待會兒" => "待會",
      "多半兒" => "多半",
      "份兒" => "份",
      "空兒" => "空",
      "人情味兒" => "人情味",
      "活兒" => "活",
      "勁兒" => "勁",
      "開頭兒" => "開頭",
      "老頭兒" => "老頭",
      "字眼兒" => "字眼"
    }.freeze
    FORMS = BASES.group_by(&:last).transform_values { |pairs| pairs.map(&:first) }.freeze

    module_function

    def base(text) = BASES[text.to_s]

    def forms(text) = FORMS.fetch(text.to_s, [])

    def spellings(text) = [text.to_s, base(text)].compact
  end
end
