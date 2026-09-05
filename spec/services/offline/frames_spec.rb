# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offline::Frames do
  def pipe
    reader, writer = IO.pipe
    reader.binmode
    writer.binmode
    [reader, writer]
  end

  it "carries an object across a pipe intact" do
    reader, writer = pipe
    described_class.write(writer, {"locale" => "ru", "paths" => ["/hanzi"], "m" => "<p>不</p>"})
    writer.close

    expect(described_class.read(reader)).to(eq({"locale" => "ru", "paths" => ["/hanzi"], "m" => "<p>不</p>"}))
  end

  it "keeps consecutive frames apart" do
    reader, writer = pipe
    described_class.write(writer, {"n" => 1})
    described_class.write(writer, {"n" => 2})
    writer.close

    expect(Array.new(3) { described_class.read(reader) }).to(eq([{"n" => 1}, {"n" => 2}, nil]))
  end

  it "answers nil when the writer went away" do
    reader, writer = pipe
    writer.close

    expect(described_class.read(reader)).to(be_nil)
  end

  it "answers nil for a frame cut short" do
    reader, writer = pipe
    writer.write([100].pack("Q>"), "{}")
    writer.close

    expect(described_class.read(reader)).to(be_nil)
  end
end
