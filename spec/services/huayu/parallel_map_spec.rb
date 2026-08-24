# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ParallelMap do
  it "maps every item on the serial path" do
    items = (1..300).to_a

    expect(described_class.call(items, workers: 1) { |value| value * 2 }).to(eq(items.map { |value| value * 2 }))
  end

  it "maps a collection too small to be worth splitting" do
    expect(described_class.call([1, 2, 3]) { |value| value + 1 }).to(eq([2, 3, 4]))
  end

  it "refuses to pass a dead worker off as an empty slice" do
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      writer.close
      exit!(1)
    end

    writer.close

    expect { described_class.collect([[pid, reader]]) }.to(raise_error(described_class::Error, /1 of 1/))
  end
end
