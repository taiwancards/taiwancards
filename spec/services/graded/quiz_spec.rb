# frozen_string_literal: true

require "rails_helper"

RSpec.describe Graded::Quiz do
  let(:analyzer) { Huayu::TextAnalyzer.new }

  def quiz_for(text) = described_class.new(text, tokens: analyzer.analyze_map(text.lines.map(&:zh)))

  it "builds the same well formed tasks for a text every time" do
    text = Graded::Library.texts(Graded::Library.tiers.first).first

    first = quiz_for(text).exercises
    expect(quiz_for(text).exercises).to(eq(first))
    first.each do |task|
      case task.kind
      when "meaning", "cloze"
        expect(task.options.size).to(eq(4))
        expect(task.options.uniq.size).to(eq(4))
        expect(task.answer).to(be_between(0, 3))
      when "order"
        expect(task.order.sort).to(eq((0...task.chunks.size).to_a))
        expect(task.order).not_to(eq(task.order.sort))
      when "pair"
        expect(task.pairs.size).to(eq(4))
      end
    end
  end

  it "blanks a word the line holds exactly once and offers rivals not already in it" do
    Graded::Library.all.first(20).each do |text|
      cloze = quiz_for(text).exercises.find { |task| task.kind == "cloze" }
      next if cloze.nil?

      expect(cloze.zh.scan("＿＿").size).to(eq(1))
      wrong = cloze.options.each_with_index.reject { |_option, index| index == cloze.answer }.map(&:first)
      expect(wrong.none? { |option| cloze.zh.include?(option) }).to(be(true))
    end
  end

  it "gives every text at least three tasks" do
    expect(Graded::Library.all.map { |text| quiz_for(text).size }.min).to(be >= 3)
  end
end
