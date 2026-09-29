# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collections::Import::Resolver do
  let(:user) { create(:user) }

  def word(text, pinyin, kind: :word) = create(:lexeme, kind:, text:, readings: {"pinyin" => pinyin})

  def row(*candidates, pinyin: nil, line: 1)
    Collections::Import::Parser::Row.new(line:, original: candidates.first, candidates:, pinyin:)
  end

  def resolve(*rows) = described_class.new(user).call(rows)

  it "takes a traditional word that is in the dictionary as it is" do
    school = word("學校", "xuéxiào")

    result = resolve(row("學校"))

    expect(result.ready.map(&:lexeme)).to(eq([school]))
    expect(result.converted).to(be_empty)
  end

  it "converts simplified spelling only when exactly one Taiwanese word matches" do
    hair = word("頭髮", "tóufǎ")

    result = resolve(row("头发"))

    expect(result.converted.map(&:lexeme)).to(eq([hair]))
    expect(result.converted.first.from).to(eq("头发"))
  end

  it "lets the reading choose between spellings, and otherwise asks" do
    send = word("發", "fā", kind: :character)
    hair = word("髮", "fǎ", kind: :character)

    expect(resolve(row("发", pinyin: "fa3")).ready.map(&:lexeme)).to(eq([hair]))
    expect(resolve(row("发", pinyin: "fā")).ready.map(&:lexeme)).to(eq([send]))
    expect(resolve(row("发")).choices.first.options).to(contain_exactly(send, hair))
  end

  it "prefers the reading the learner wrote over a traditional look-alike" do
    word("干", "gān", kind: :character)
    busy = word("幹", "gàn", kind: :character)

    expect(resolve(row("干", pinyin: "gan4")).ready.map(&:lexeme)).to(eq([busy]))
  end

  it "prefers Taiwanese orthography when both spellings are in the dictionary" do
    inside = word("裡面", "lǐmiàn")
    word("裏面", "lǐmiàn")

    expect(resolve(row("里面")).ready.map(&:lexeme)).to(eq([inside]))
  end

  it "rewrites other traditional orthographies into the Taiwanese one" do
    inside = word("裡面", "lǐmiàn")
    word("裏面", "lǐmiàn")

    result = resolve(row("裏面"))

    expect(result.ready.map(&:lexeme)).to(eq([inside]))
    expect(result.converted.first.from).to(eq("裏面"))
  end

  it "leaves out a word the dictionary only has in a non-Taiwanese spelling" do
    word("水着", "shuǐzhe")

    expect(resolve(row("水着")).missing.map(&:original)).to(eq(["水着"]))
  end

  it "asks when a character is both simplified and traditional and nothing tells them apart" do
    queen = word("后", "hòu", kind: :character)
    after = word("後", "hòu", kind: :character)

    expect(resolve(row("后")).choices.first.options).to(eq([queen, after]))
  end

  it "prefers everyday characters over rare variants" do
    eat = word("吃飯", "chīfàn")
    word("喫飯", "chīfàn", kind: :collocation)

    expect(resolve(row("吃饭")).ready.map(&:lexeme)).to(eq([eat]))
  end

  it "holds back words used in China and offers the Taiwanese one" do
    info = word("資訊", "zīxùn")

    item = resolve(row("信息")).china.first

    expect(item.term).to(eq("信息"))
    expect(item.taiwan).to(eq([info]))
  end

  it "holds back words Taiwan usually says differently, even after conversion" do
    film = word("影片", "yǐngpiàn")
    word("視頻", "shìpín")

    item = resolve(row("视频")).china.first

    expect(item.term).to(eq("視頻"))
    expect(item.taiwan).to(include(film))
  end

  it "reports what is not in the dictionary and what repeats" do
    word("學校", "xuéxiào")

    result = resolve(row("學校", line: 1), row("學校", line: 2), row("你好嗎", line: 3))

    expect(result.ready.size).to(eq(1))
    expect(result.duplicates.map(&:line)).to(eq([2]))
    expect(result.missing.map(&:original)).to(eq(["你好嗎"]))
  end

  it "knows which words the learner already has" do
    school = word("學校", "xuéxiào")
    LexemeMemory.create!(lexeme: school, user:, facet: :recognition, activated_at: Time.current, state: :review)

    result = resolve(row("學校"))

    expect(result.covered_ids).to(include(school.id))
    expect(result.fresh_ids).to(be_empty)
  end
end
