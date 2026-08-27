# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::LevelScale do
  def scale(table, ceiling: 7)
    described_class.new(table, ceiling:)
  end

  it "files a text at the level that covers everything and calls it exact" do
    placement = scale({"甲" => 1, "乙" => 2}).place(%w[甲 乙])

    expect(placement.index).to(eq(2))
    expect(placement.exact).to(be(true))
    expect(placement.unknown).to(eq(0))
  end

  it "lets a quarter of the units sit up to two levels above, and marks that inexact" do
    table = %w[甲 乙 丙].index_with(2).merge("丁" => 4)
    placement = scale(table).place(%w[甲 乙 丙 丁])

    expect(placement.index).to(eq(2))
    expect(placement.exact).to(be(false))
  end

  it "refuses the lower level when a unit sits more than two levels above it" do
    table = %w[甲 乙 丙].index_with(2).merge("丁" => 7)
    placement = scale(table).place(%w[甲 乙 丙 丁])

    expect(placement.index).to(eq(5))
  end

  it "leaves the allowance inert below four characters" do
    placement = scale({"甲" => 1, "乙" => 1, "丙" => 6}).place(%w[甲 乙 丙])

    expect(placement.index).to(eq(6))
    expect(placement.exact).to(be(true))
  end

  it "reads a unit it does not know character by character" do
    placement = scale({"甲" => 2, "乙" => 3}).place(["甲乙"])

    expect(placement.index).to(eq(3))
    expect(placement.unknown).to(eq(0))
  end

  it "gives no level when a quarter of the text stays unreadable" do
    placement = scale({"甲" => 1}).place(%w[甲 乙 丙 丁])

    expect(placement.index).to(be_nil)
    expect(placement.exact).to(be(false))
  end

  it "counts the unreadable pieces it did tolerate" do
    table = %w[甲 乙 丙].index_with(2)
    placement = scale(table).place(%w[甲 乙 丙 丁])

    expect(placement.index).to(eq(2))
    expect(placement.unknown).to(eq(1))
    expect(placement.exact).to(be(false))
  end

  it "never resolves a term through itself" do
    placement = scale({"甲乙" => 1, "甲" => 4, "乙" => 4}).place(["甲乙"], excluding: "甲乙")

    expect(placement.index).to(eq(4))
  end
end
