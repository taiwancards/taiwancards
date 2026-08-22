# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Cepstra do
  let(:rows) { [[1.0, 2.0], [3.0, 4.0], [5.0, 12.0]] }

  let(:spectra) do
    Class
      .new do
        def initialize(rows) = @rows = rows

        def length = @rows.length

        def [](index) = @rows[index]
      end
      .new(rows)
  end

  let(:mfcc) { Class.new { def call(row) = row }.new }

  def build = described_class.new(spectra:, mfcc:, size: 2)

  it "passes rows through untouched before normalizing" do
    expect(build[1]).to(eq([3.0, 4.0]))
  end

  it "centres the rows on the mean of the range it was given" do
    cepstra = build.normalize(0..1)

    expect(cepstra[0]).to(eq([-1.0, -1.0]))
    expect(cepstra[1]).to(eq([1.0, 1.0]))
  end

  it "applies the same mean to rows outside the range" do
    expect(build.normalize(0..1)[2]).to(eq([3.0, 9.0]))
  end

  it "leaves rows alone when the range holds nothing" do
    expect(build.normalize(9..12)[0]).to(eq([1.0, 2.0]))
  end

  it "reads each row from the spectra once" do
    cepstra = build
    3.times { cepstra[1] }

    expect(cepstra.computed).to(eq(1))
  end

  it "answers nil outside its range" do
    expect(build[7]).to(be_nil)
  end
end
