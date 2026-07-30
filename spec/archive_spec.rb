# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the cold archive" do
  let(:script) { Rails.root.join("bin/distribute").read }

  let(:skipped) do
    script[/^UNPACKED_FROM_XZ=\((.*?)\)/m, 1].to_s.split.map { |entry| Rails.root.join(entry) }
  end

  it "skips only files that decompress back out of a neighboring archive" do
    expect(skipped).not_to(be_empty)

    skipped.each do |path|
      expect(Pathname.new("#{path}.xz")).to(exist)
    end
  end

  it "restores what it skipped when pulling" do
    expect(script).to(match(/do_pull\(\).*xz -dk/m))
  end

  it "keeps the rebuild sources the audit demands" do
    required = Huayu::SourceAudit.new.report.select { |row| row[:required] }.map { |row| row[:path].to_s }

    skipped.each do |path|
      next unless required.include?(path.to_s)

      expect(script).to(include(path.relative_path_from(Rails.root).to_s))
    end
  end
end
