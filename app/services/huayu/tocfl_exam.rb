# frozen_string_literal: true

module Huayu
  class TocflExam
    Level = Data.define(:number, :novice, :zh, :band, :cefr, :words, :listening, :reading)

    LEVELS = [
      Level.new(
        number: 1,
        novice: true,
        zh: "準備級一級",
        band: nil,
        cefr: nil,
        words: nil,
        listening: 190,
        reading: 195
      ),
      Level.new(
        number: 2,
        novice: true,
        zh: "準備級二級",
        band: nil,
        cefr: nil,
        words: nil,
        listening: 295,
        reading: 305
      ),
      Level.new(
        number: 1,
        novice: false,
        zh: "入門級",
        band: "A",
        cefr: "A1",
        words: "500",
        listening: 355,
        reading: 355
      ),
      Level.new(
        number: 2,
        novice: false,
        zh: "基礎級",
        band: "A",
        cefr: "A2",
        words: "1,000",
        listening: 435,
        reading: 450
      ),
      Level.new(
        number: 3,
        novice: false,
        zh: "進階級",
        band: "B",
        cefr: "B1",
        words: "2,500",
        listening: 480,
        reading: 490
      ),
      Level.new(
        number: 4,
        novice: false,
        zh: "高階級",
        band: "B",
        cefr: "B2",
        words: "5,000",
        listening: 555,
        reading: 570
      ),
      Level.new(
        number: 5,
        novice: false,
        zh: "流利級",
        band: "C",
        cefr: "C1",
        words: "8,000",
        listening: 600,
        reading: 610
      ),
      Level.new(
        number: 6,
        novice: false,
        zh: "精通級",
        band: "C",
        cefr: "C2",
        words: "8,000+",
        listening: 655,
        reading: 690
      )
    ].freeze

    MAX_SCORE = 700

    OFFICIAL = {
      registration: "https://tocfl.edu.tw/TW/",
      schedule: "https://tocfl.edu.tw/tocfl/index.php/sign_up/tw/list/1",
      standards: "https://tocfl.edu.tw/tocfl/index.php/test/cat/list/3",
      scholarships: "https://tocfl.edu.tw/tocfl/index.php/certificate/scholarship",
      papers: "https://tocfl.edu.tw/tocfl/index.php/exam/test/page/1"
    }.freeze
  end
end
