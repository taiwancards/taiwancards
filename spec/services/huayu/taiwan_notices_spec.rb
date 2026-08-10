# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TaiwanNotices do
  before { described_class.reset! }

  after { described_class.reset! }

  it "loads every notice in the shipped file" do
    expect(described_class.all).not_to(be_empty)
  end

  it "keeps the notices in the order the file gives them" do
    positions = described_class.all.map(&:position)
    expect(positions).to(eq(positions.sort))
  end

  it "gives every notice a title and an issuer in both languages" do
    described_class.all.each do |notice|
      expect(notice.zh).to(be_present)
      expect(notice.name(:en)).to(be_present)
      expect(notice.name(:ru)).to(be_present)
      expect(notice.issuer_name(:ru)).to(be_present)
    end
  end

  it "gives every line a Chinese text and both translations" do
    described_class.all.flat_map(&:items).each do |item|
      expect(item.zh).to(be_present)
      expect(item.name(:en)).to(be_present)
      expect(item.name(:ru)).to(be_present)
    end
  end

  it "carries no personal name, address or telephone number" do
    text = described_class
      .all
      .flat_map { |notice| [notice.zh, notice.issuer["zh"], notice.doc, *notice.sentences] }
      .join
    expect(text).not_to(match(/\d{4}-\d{4}/))
    expect(text).not_to(match(/[路街巷弄]\s*\d/))
    expect(text).not_to(include("克拉美地"))
  end

  it "finds a notice by its id and groups them by category" do
    notice = described_class.all.first
    expect(described_class.find(notice.id)).to(eq(notice))
    expect(described_class.in_category(notice.category)).to(include(notice))
  end

  it "marks the poster-style notice as steps" do
    steps = described_class.all.select(&:steps?)
    expect(steps).not_to(be_empty)
    expect(steps.flat_map(&:items).map(&:head)).to(all(be_present))
  end
end
