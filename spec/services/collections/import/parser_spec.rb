# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collections::Import::Parser do
  def rows(source, text) = described_class.call(source, text).rows

  describe "Pleco" do
    it "reads a text export, keeps the traditional headword and skips category lines" do
      text = "﻿//Lesson 1\n学校[學校]\txue2xiao4\tschool\n老師\tlao3shi1\tteacher\n\n"

      parsed = rows("pleco", text)

      expect(parsed.map(&:candidates)).to(eq([%w[學校 学校], %w[老師]]))
      expect(parsed.map(&:pinyin)).to(eq(%w[xue2xiao4 lao3shi1]))
    end

    it "reads an XML export" do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <plecoflash><cards>
          <card><entry><headword charset="sc">头发</headword><headword charset="tc">頭髮</headword><pron type="hypy">tou2fa5</pron></entry></card>
          <card><entry><headword charset="tc">學校</headword><headword charset="sc">學校</headword><pron type="hypy">xue2xiao4</pron></entry></card>
        </cards></plecoflash>
      XML

      expect(rows("pleco", xml).map(&:candidates)).to(eq([%w[頭髮 头发], %w[學校]]))
    end
  end

  describe "Anki" do
    it "honors the declared separator, strips HTML and sound tags, and finds the character column" do
      text = <<~TXT
        #separator:semicolon
        #html:true
        <b>school</b>;<span>學校</span>[sound:xuexiao.mp3];xué xiào
        teacher;"老師 (lǎoshī)";lǎo shī
      TXT

      parsed = rows("anki", text)

      expect(parsed.map(&:candidates)).to(eq([%w[學校], %w[老師]]))
      expect(parsed.map(&:pinyin)).to(eq(["xué xiào", "lǎo shī"]))
    end
  end

  describe "Quizlet" do
    it "reads a pasted set whichever side holds the characters" do
      expect(rows("quizlet", "school\t學校\nteacher\t老師").map(&:candidates)).to(eq([%w[學校], %w[老師]]))
      expect(rows("quizlet", "學校,school;老師,teacher").map(&:candidates)).to(eq([%w[學校], %w[老師]]))
    end

    it "keeps every alternative spelling in one field, in order" do
      expect(rows("quizlet", "裏面／裡面\tinside").first.candidates).to(eq(%w[裏面 裡面]))
    end
  end

  it "counts rows it could not read instead of guessing" do
    result = described_class.call("quizlet", "學校\tschool\nhello\tworld")

    expect(result.rows.size).to(eq(1))
    expect(result.skipped).to(eq(1))
  end

  it "calls a file without any Chinese unreadable" do
    expect(described_class.call("anki", "front\tback\nfoo\tbar").unreadable).to(be(true))
  end

  it "refuses a file over the size limit" do
    big = "學" * (described_class::MAX_BYTES / 3 + 10)

    expect(described_class.call("pleco", big).unreadable).to(be(true))
  end

  it "reads only the first rows of a very long list and says so" do
    stub_const("#{described_class}::MAX_ROWS", 2)

    result = described_class.call("quizlet", "學校\ta\n老師\tb\n朋友\tc")

    expect(result.rows.size).to(eq(2))
    expect(result.truncated).to(be(true))
    expect(result.total).to(eq(3))
  end
end
