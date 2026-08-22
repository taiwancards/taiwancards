# frozen_string_literal: true

module Huayu
  module Cangjie
    KEYS = {
      "a" => "日",
      "b" => "月",
      "c" => "金",
      "d" => "木",
      "e" => "水",
      "f" => "火",
      "g" => "土",
      "h" => "竹",
      "i" => "戈",
      "j" => "十",
      "k" => "大",
      "l" => "中",
      "m" => "一",
      "n" => "弓",
      "o" => "人",
      "p" => "心",
      "q" => "手",
      "r" => "口",
      "s" => "尸",
      "t" => "廿",
      "u" => "山",
      "v" => "女",
      "w" => "田",
      "x" => "難",
      "y" => "卜",
      "z" => "重"
    }.freeze

    ROWS = [%w[q w e r t y u i o p], %w[a s d f g h j k l], %w[z x c v b n m]].freeze

    SUPERSEDED = {
      "修" => "oloh",
      "倏" => "olok",
      "儵" => "olof",
      "凳" => "nthn",
      "條" => "olod",
      "絛" => "olof",
      "脩" => "olob",
      "鯈" => "olof"
    }.freeze

    PREFERRED = {
      "亮" => "yrbu",
      "彪" => "yuhhh",
      "唬" => "rypu",
      "號" => "rsypu",
      "琥" => "mgypu",
      "虎" => "yphu",
      "褫" => "lhyu",
      "遞" => "yhyu",
      "尷" => "kusmt",
      "檻" => "dsmt",
      "濫" => "esmt",
      "監" => "smbt",
      "籃" => "hsmt",
      "艦" => "hysmt",
      "藍" => "tsmt",
      "襤" => "lsmt",
      "鑑" => "csmt",
      "咨" => "mor",
      "姿" => "mov",
      "恣" => "mop",
      "懿" => "gtmop",
      "次" => "mmno",
      "瓷" => "momvn",
      "資" => "mobuc",
      "諮" => "yrmor",
      "均" => "gpmm",
      "昀" => "apmm",
      "鈞" => "cpmm",
      "嘛" => "rijc",
      "怵" => "pijc",
      "麻" => "ijcc",
      "述" => "yijc",
      "蜈" => "lirvk",
      "虞" => "yprvk",
      "誤" => "yrrvk",
      "氯" => "onvne",
      "碌" => "mrvne",
      "拔" => "qikk",
      "跋" => "rmikk",
      "鈸" => "cikk",
      "髮" => "shikk",
      "珊" => "mgbt",
      "跚" => "rmbt",
      "奏" => "qkmk",
      "忝" => "mkp",
      "添" => "emkp",
      "舔" => "hrmkp",
      "塭" => "gwot",
      "瘟" => "kwot",
      "諺" => "yrykh",
      "鏟" => "cykm",
      "務" => "nhoks",
      "圖" => "wryw",
      "墟" => "gypm",
      "害" => "jqmr",
      "廣" => "itmc",
      "微" => "houuk",
      "拐" => "qrsh",
      "梁" => "eid",
      "粱" => "eifd",
      "賴" => "dlshc",
      "衷" => "ylhv",
      "隙" => "nlfhf",
      "風" => "hnmli",
      "鶴" => "oghaf",
      "龜" => "nxu",
      "邸" => "hmnl",
      "窗" => "jchwk",
      "聚" => "seooo",
      "蘸" => "tmwf"
    }.freeze

    CANONICAL = SUPERSEDED.merge(PREFERRED).freeze

    module_function
    def canonical(char, code) = CANONICAL.fetch(char, code)

    def radicals(code)
      code.to_s.downcase.each_char.filter_map { |letter| KEYS[letter] }.join
    end
  end
end
