# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::GlossCollisions do
  let(:definitions) { Rails.root.join("tmp/spec-mmh-#{SecureRandom.hex(4)}.txt") }
  let(:mapping) { Rails.root.join("tmp/spec-st-#{SecureRandom.hex(4)}.txt") }

  after do
    definitions.delete if definitions.exist?
    mapping.delete if mapping.exist?
  end

  def write(entries, pairs)
    definitions.dirname.mkpath
    definitions.write(entries.map { |char, gloss| JSON.generate({character: char, definition: gloss}) }.join("\n"))
    mapping.write(pairs.map { |simplified, traditional| "#{simplified}\t#{traditional}" }.join("\n"))
  end

  it "flags a traditional character that shares its gloss with a same-simplified twin" do
    write({"離" => "rare beast; strange; elegant", "离" => "rare beast; strange; elegant"}, {"离" => "離"})

    expect(described_class.new(definitions:, mapping:).call).to(
      eq({"離" => "rare beast; strange; elegant", "离" => "rare beast; strange; elegant"})
    )
  end

  it "leaves an ordinary pair alone when the simplified form is not traditional itself" do
    write({"練" => "to drill, to exercise", "练" => "to drill, to exercise"}, {"练" => "練"})

    expect(described_class.new(definitions:, mapping:).call).to(be_empty)
  end

  it "leaves distinct glosses alone" do
    write({"隻" => "single, solitary", "只" => "only, merely"}, {"只" => "隻 只"})

    expect(described_class.new(definitions:, mapping:).call).to(be_empty)
  end

  it "flags both members when two traditional forms map to one simplified" do
    write({"髒" => "organs; dirty", "臟" => "organs; dirty"}, {"脏" => "髒 臟"})

    expect(described_class.new(definitions:, mapping:).call.keys).to(contain_exactly("髒", "臟"))
  end

  it "returns nothing when the reference files are missing" do
    expect(described_class.new(definitions: Rails.root.join("tmp/absent.txt"), mapping:).call).to(be_empty)
  end
end
