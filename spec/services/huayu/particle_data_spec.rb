# frozen_string_literal: true

require "rails_helper"

RSpec.describe "mood particle data" do
  let(:entries) { JSON.parse(Huayu::ParticleImporter::PATH.read) }
  let(:simplified) { TWFilter::Tables.set("simplified_only.txt") }

  it "leaves no entry behind" do
    importer = Huayu::ParticleImporter.new
    skipped = entries.reject { |entry| importer.send(:valid?, entry) }

    expect(skipped.map { |entry| entry["text"] }).to(be_empty)
  end

  it "ranks them from one with no gaps and no ties" do
    expect(entries.map { |entry| entry["rank"] }.sort).to(eq((1..entries.length).to_a))
  end

  it "keeps every headword and every variant spelling distinct" do
    spellings = entries.flat_map { |entry| [entry["text"], *Array(entry["variants"]).map { |row| row["text"] }] }

    expect(spellings.tally.select { |_, count| count > 1 }).to(be_empty)
  end

  it "writes both languages for the summary, the force and the body" do
    incomplete = entries.reject { |entry|
      %w[summary_en summary_ru force_en force_ru].all? { |field| entry[field].to_s.present? } &&
        entry["body_en"].present? &&
        entry["body_ru"].present?
    }

    expect(incomplete.map { |entry| entry["text"] }).to(be_empty)
  end

  it "translates and annotates every example in both languages" do
    thin = entries.flat_map { |entry|
      Array(entry["examples"]).filter_map { |row|
        "#{entry["text"]}: #{row["zh"]}" unless %w[zh en ru note_en note_ru].all? { |field| row[field].to_s.present? }
      }
    }

    expect(thin).to(be_empty)
  end

  it "holds only traditional characters used in Taiwan" do
    offenders = entries.filter_map { |entry|
      found = entry.to_json.each_char.select { |char| simplified.include?(char) }.uniq
      "#{entry["text"]}: #{found.join}" if found.any?
    }

    expect(offenders).to(be_empty)
  end

  it "names a family the section knows and both locales can label" do
    entries.each do |entry|
      expect(ZhuciController::FAMILIES).to(include(entry["family"]), entry["text"])
      %i[en ru].each do |locale|
        expect(I18n.exists?("zhuci.families.#{entry["family"]}", locale)).to(be(true))
      end
    end
  end

  it "points only at grammar lessons that exist" do
    dangling = entries.filter_map { |entry|
      slug = entry["grammar"].presence
      "#{entry["text"]} → #{slug}" if slug && Huayu::GrammarLessons.find(slug).nil?
    }

    expect(dangling).to(be_empty)
  end
end
