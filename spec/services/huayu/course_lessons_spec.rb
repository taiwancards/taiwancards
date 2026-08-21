# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CourseLessons do
  before { described_class.reset! }

  after { described_class.reset! }

  it "loads every stage in order with a band label" do
    expect(described_class.stages.map(&:slug)).to(eq(%w[novice1 novice2 a1 a2 b1]))
    expect(described_class.stages.map(&:band)).to(all(start_with("TOCFL")))
  end

  it "numbers the lessons from one with no gaps" do
    numbers = described_class.lessons.map(&:number)

    expect(numbers).to(eq((1..numbers.size).to_a))
  end

  it "puts every lesson in a stage that exists" do
    known = described_class.stages.map(&:slug).to_set

    expect(described_class.lessons.map(&:stage).uniq).to(all(satisfy { |slug| known.include?(slug) }))
  end

  it "points every grammar reference at a real grammar lesson" do
    missing = described_class.lessons.flat_map { |lesson| lesson.grammar.reject(&:lesson).map(&:slug) }

    expect(missing).to(be_empty)
  end

  it "gives each lesson a text, words, a culture note and tasks" do
    described_class.lessons.each do |lesson|
      expect(lesson.lines.size).to(be >= 5, "#{lesson.slug} has too few lines")
      expect(lesson.vocabulary.size).to(be >= 10, "#{lesson.slug} has too few words")
      expect(lesson.exercises.size).to(be >= 6, "#{lesson.slug} has too few tasks")
      expect(lesson.culture_for(:ru)).to(be_present, "#{lesson.slug} has no Russian culture note")
    end
  end

  it "carries a reading for every vocabulary item" do
    unread = described_class.lessons.flat_map { |lesson| lesson.vocabulary.reject { |word| word.zhuyin.present? } }

    expect(unread.map(&:zh)).to(be_empty)
  end

  it "writes Taiwan with 臺 in its own Chinese" do
    chinese = described_class.lessons.flat_map { |lesson| lesson.lines.map(&:zh) + lesson.words + [lesson.zh_title] }

    expect(chinese.grep(/台灣/)).to(be_empty)
  end

  it "builds a level test for every stage that has lessons" do
    described_class.stages.each do |stage|
      next if described_class.by_stage[stage.slug].blank?

      expect(stage.exam.size).to(be >= 15, "#{stage.slug} has too small a test")
    end
  end

  it "gives every task a well formed answer" do
    tasks = described_class.lessons.flat_map(&:exercises) + described_class.stages.flat_map(&:exam)

    tasks.each do |task|
      case task.kind
      when "meaning", "word", "cloze", "reading", "reply", "street"
        expect(task.options.size).to(eq(4))
        expect(task.answer).to(be_between(0, 3))
      when "order"
        expect(task.order.sort).to(eq((0...task.chunks.size).to_a))
      when "pair"
        expect(task.order.sort).to(eq((0...task.pairs.size).to_a))
      end
    end
  end

  it "gives every dialogue at least two speakers" do
    lonely = described_class.lessons.select do |lesson|
      lesson.dialogue? && lesson.lines.filter_map(&:who).uniq.size < 2
    end

    expect(lonely.map(&:slug)).to(be_empty)
  end

  it "keeps a passage free of speaker labels" do
    labelled = described_class.lessons.reject(&:dialogue?).select { |lesson| lesson.lines.any?(&:who) }

    expect(labelled.map(&:slug)).to(be_empty)
  end

  it "carries a pinyin reading beside every zhuyin one" do
    silent = described_class.lessons.flat_map { |lesson| lesson.vocabulary.reject { |word| word.pinyin.present? } }

    expect(silent.map(&:zh)).to(be_empty)
  end

  it "translates every word rather than repeating it back in characters" do
    untranslated = described_class.lessons.flat_map do |lesson|
      lesson.vocabulary.reject { |word| word.en.to_s.match?(/[A-Za-z]/) && word.ru.to_s.match?(/\p{Cyrillic}/) }
    end

    expect(untranslated.map(&:zh)).to(be_empty)
  end

  it "asks every task in a form the page knows how to draw" do
    kinds = (described_class.lessons.flat_map(&:exercises) + described_class.stages.flat_map(&:exam)).map(&:kind)

    expect(kinds.uniq).to(all(be_in(%w[meaning word reading cloze reply street order pair])))
  end

  it "never offers the same option twice in one task" do
    tasks = described_class.lessons.flat_map(&:exercises) + described_class.stages.flat_map(&:exam)
    repeated = tasks.select { |task| task.options.any? && task.options.size != task.options.uniq.size }

    expect(repeated.map(&:zh)).to(be_empty)
  end

  it "mixes reading aloud with reading off the page" do
    kinds = described_class.lessons.map(&:kind).tally

    expect(kinds["dialogue"]).to(be >= 20)
    expect(kinds["passage"]).to(be >= 10)
  end

  it "finds a lesson by slug and knows its neighbours" do
    lesson = described_class.lessons[1]
    previous, following = described_class.neighbours(lesson)

    expect(described_class.find(lesson.slug)).to(eq(lesson))
    expect(previous).to(eq(described_class.lessons.first))
    expect(following).to(eq(described_class.lessons[2]))
  end
end
