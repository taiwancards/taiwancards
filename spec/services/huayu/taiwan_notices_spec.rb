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
      expect(notice.issuer_name(:ru)).to(be_present) unless notice.form?
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

  it "puts every entry in a known life situation" do
    expect(described_class.all.map(&:situation) - described_class::SITUATIONS).to(be_empty)
    expect(described_class.by_situation.values.flatten).to(match_array(described_class.all))
  end

  it "gives every form labeled fields explained in both languages" do
    forms = described_class.all.select(&:form?)
    expect(forms).not_to(be_empty)

    forms.each do |form|
      expect(form.about_text(:en)).to(be_present)
      expect(form.about_text(:ru)).to(be_present)
      expect(form.fields.size + form.items.size).to(be_positive)
      form.fields.each do |field|
        expect(field.zh).to(be_present)
        expect(field.name(:en)).to(be_present)
        expect(field.name(:ru)).to(be_present)
        next if field.heading?

        expect(field.note(:en)).to(be_present)
        expect(field.note(:ru)).to(be_present)
      end
    end
  end

  it "keeps form explanations apart from the translations a notice line carries" do
    item = described_class.all.flat_map(&:items).find { |candidate| candidate.notes.present? }
    expect(item.names.keys).not_to(include("note"))
    expect(item.note(:en)).not_to(eq(item.name(:en)))
  end

  it "prints no real hospital, bank or company on a form" do
    described_class.all.select(&:form?).each do |form|
      issuer = form.issuer["zh"].to_s
      expect(issuer.empty? || issuer.include?("○○")).to(be(true), "#{form.id} names #{issuer}")
    end
  end

  it "marks the poster-style notice as steps" do
    steps = described_class.all.select(&:steps?)
    expect(steps).not_to(be_empty)
    expect(steps.flat_map(&:items).map(&:head)).to(all(be_present))
  end
end
