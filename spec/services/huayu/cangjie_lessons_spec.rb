# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CangjieLessons do
  it "carries a lesson for every Cangjie key" do
    keys = described_class.all.filter_map(&:key)

    expect(keys).to(match_array(Huayu::Cangjie::KEYS.keys))
  end

  it "spells every code the same way the keyboard does" do
    rows = described_class.all.flat_map { |lesson| lesson.bank + walk_rows(lesson) }

    wrong = rows.reject { |row| Huayu::Cangjie.radicals(row["code"]) == row["parts"].join }

    expect(wrong.map { |row| row["char"] }).to(be_empty)
  end

  it "never shows a letter lesson an example that skips its own key" do
    stray = described_class.all.select(&:letter?).flat_map do |lesson|
      next [] if lesson.key == "z"

      lesson.bank.reject { |row| row["code"].include?(lesson.key) }.map { |row| "#{lesson.slug}:#{row["char"]}" }
    end

    expect(stray).to(be_empty)
  end

  it "never teaches a code the fifth generation replaced" do
    third = %w[
      aimlu
      pkf
      bnui
      hdhn
      hhj
      hxe
      hxysf
      igb
      ighaf
      igp
      itwc
      lwlv
      lmyyy
      lmmm
      mbrrm
      mdylm
      mldh
      mwyl
      nui
      nomrn
      olhb
      olhd
      olhf
      olhh
      olhk
      omrt
      xomrt
      xhs
      syyq
      syyi
      xthjd
      twc
      ttj
      neu
      yrbbn
      yrbvn
    ]
    codes = described_class.all.flat_map { |lesson| lesson.bank.map { |row| row["code"] } }

    expect(codes & third).to(be_empty)
  end

  it "keeps every code inside the five-key ceiling" do
    codes = described_class.all.flat_map { |lesson| lesson.bank.map { |row| row["code"] } }

    expect(codes.map(&:length).max).to(be <= 5)
  end

  it "gives every drill a reachable answer" do
    tasks = described_class.all.flat_map(&:drills)

    choices = tasks.reject { |task| task["kind"] == "code" }
    expect(choices).to(all(satisfy { |task| task["options"][task["answer"]].present? }))
    typing = tasks.select { |task| task["kind"] == "code" }
    expect(typing).to(all(satisfy { |task| task["code"].present? }))
  end

  it "files the whole 4808 list under the key each code opens with" do
    index = described_class.all.filter_map { |lesson| lesson.index.presence }

    expect(index.size).to(eq(24))
    expect(index.sum(&:size)).to(be >= 4_800)
    expect(index.flatten).to(all(satisfy { |row| row["code"].present? && row["char"].present? }))
  end

  it "opens every key index with its most frequent characters" do
    lesson = described_class.find("a")

    expect(lesson.index.first(3).map { |row| row["char"] }).to(eq(%w[是 時 開]))
  end

  it "files every Novice and A1 character under a key, badge and all" do
    levels = described_class.all.flat_map(&:index).group_by { |row| row["level"] }

    expect(levels["Novice1"].size).to(eq(77))
    expect(levels["Novice2"].size).to(eq(88))
    expect(levels["A1"].size).to(eq(100))
  end

  it "finds a lesson by slug and walks to its neighbours" do
    lesson = described_class.find("a")
    previous, following = described_class.neighbours(lesson)

    expect(lesson.letter).to(eq("日"))
    expect(previous.slug).to(eq("count"))
    expect(following.slug).to(eq("b"))
  end

  it "returns nothing for a slug it does not know" do
    expect(described_class.find("nope")).to(be_nil)
  end

  it "builds the frequency core for the speed trainer" do
    core = described_class.core

    expect(core.size).to(eq(120))
    expect(core.first(6).map { |row| row["char"] }).to(eq(%w[的 一 是 不 我 有]))
    expect(core).to(all(satisfy { |row| Huayu::Cangjie.radicals(row["code"]).present? }))
  end

  it "puts every Novice and A1 character into the exam pool" do
    exam = described_class.exam
    listed = described_class
      .all
      .flat_map(&:index)
      .select { |row| %w[Novice1 Novice2 A1].include?(row["level"]) }

    expect(exam.map { |row| row["char"] }).to(match_array(listed.map { |row| row["char"] }))
    expect(exam).to(all(satisfy { |row| Huayu::Cangjie.radicals(row["code"]).present? }))
  end

  def walk_rows(lesson)
    lesson.blocks.flat_map { |block| Array(block["rows"]) }.select { |row| row["char"] && row["code"] }
  end
end
