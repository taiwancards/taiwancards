# frozen_string_literal: true

module MedicineHelper
  FLOORS = [
    ["7F", 78, [["病房", 165, 150], ["護理站", 325, 140], ["安寧病房", 475, 160]]],
    ["6F", 148, [["婦產科", 165, 160], ["產房", 335, 120], ["小兒科", 465, 150]]],
    ["5F", 218, [["外科", 165, 100], ["開刀房", 275, 130], ["加護病房", 415, 160], ["恢復室", 585, 105]]],
    ["4F", 288, [["內科", 165, 110], ["家醫科", 285, 130], ["身心科", 425, 130], ["健檢", 565, 125]]],
    ["3F", 358, [["耳鼻喉科", 165, 150], ["眼科", 325, 100], ["牙科", 435, 100], ["皮膚科", 545, 145]]],
    ["2F", 428, [["骨科", 165, 100], ["X光室", 275, 120], ["復健科", 405, 130], ["檢驗室", 545, 145]]]
  ].freeze

  def med_caption(text, limit: 24)
    meaning = @by_text[text]&.meaning(I18n.locale).to_s
    meaning.split(/[;,(（]/).first.to_s.strip.truncate(limit)
  end

  def med_callouts(items, top:, gap:)
    items.each_with_index.map do |(text, anchor_x, anchor_y), index|
      {text:, ax: anchor_x, ay: anchor_y, ly: top + (index * gap)}
    end
  end
end
