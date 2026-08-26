# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Taiwan vocabulary data" do
  def skipped(importer)
    entries = JSON.parse(importer.instance_variable_get(:@path).read)
    entries.reject { |entry| importer.send(:valid?, entry) }.map { |entry| entry["text"] }
  end

  it "leaves no everyday entry behind" do
    expect(skipped(Huayu::TaiwanEverydayImporter.new)).to(be_empty)
  end

  it "leaves no medicine entry behind" do
    expect(skipped(Huayu::MedicineImporter.new)).to(be_empty)
  end

  it "leaves no games entry behind" do
    expect(skipped(Huayu::GamesImporter.new)).to(be_empty)
  end

  it "carries a reading and both glosses for every common word" do
    entries = JSON.parse(Huayu::CommonWordsImporter::PATH.read)
    incomplete = entries.reject { |entry| %w[text pinyin zhuyin en ru].all? { |field| entry[field].to_s.present? } }

    expect(incomplete.map { |entry| entry["text"] }).to(be_empty)
  end

  it "names every origin, register and domain it ships" do
    entries = JSON.parse(Huayu::TaiwanEverydayImporter::PATH.read)

    expect(entries.filter_map { |entry| entry["origin"] }.uniq - Huayu::TaiwanEverydayImporter::ORIGINS).to(be_empty)
    expect(entries.filter_map { |entry| entry["register"] }.uniq - Huayu::TaiwanEverydayImporter::REGISTERS).to(
      be_empty
    )
    expect(entries.filter_map { |entry| entry["domain"] }.uniq - Huayu::TaiwanEverydayImporter::DOMAINS).to(be_empty)
  end

  it "keeps a label for every origin the importer accepts" do
    %i[en ru].each do |locale|
      Huayu::TaiwanEverydayImporter::ORIGINS.each do |origin|
        key = "everyday.origins.#{origin.tr("-", "_")}"
        expect(I18n.exists?(key, locale)).to(be(true), "expected #{key} in #{locale}")
      end
    end
  end
end
