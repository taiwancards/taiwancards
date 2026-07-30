# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::RegisterMix do
  let!(:talk) do
    ContentSource.create!(
      license_commercial: true,
      slug: "talk",
      name: "talk",
      register: :colloquial,
      attribution: "talk"
    )
  end

  let!(:press) do
    ContentSource.create!(
      license_commercial: true,
      slug: "press",
      name: "press",
      register: :publicistic,
      attribution: "press"
    )
  end

  let!(:dictionary) do
    ContentSource.create!(
      slug: "dictionary",
      license_commercial: true,
      name: "dictionary",
      register: :academic,
      attribution: "dictionary",
      style_sample: false
    )
  end

  let!(:both) { create(:lexeme, kind: :word, text: "甲") }
  let!(:only_talk) { create(:lexeme, kind: :word, text: "丙") }
  let!(:only_press) { create(:lexeme, kind: :word, text: "丁") }
  let!(:everywhere) { create(:lexeme, kind: :word, text: "的") }

  def sentence(source, segments, index)
    create(
      :lexeme,
      kind: :sentence,
      text: "#{segments.join}。#{index}",
      data: {"segments" => segments},
      content_sources: [source]
    )
  end

  before do
    @probe = 4.times.map { |i| sentence(talk, %w[甲 丙 的], i) }.first
    2.times { |i| sentence(press, %w[甲 丁 的], i) }
    10.times { |i| sentence(dictionary, %w[甲], i) }
  end

  it "reads a word as neutral when its rate per corpus is the same everywhere" do
    described_class.new(io: StringIO.new, min_tokens: 3, prior: 0.0).call

    expect(both.reload.data["register_mix"]).to(eq([0.5, nil, 0.5, nil, nil, nil, nil]))
    expect(both.data["register_n"]).to(eq(6))
  end

  it "leaves out registers whose corpus is too small to estimate" do
    described_class.new(io: StringIO.new, min_tokens: 7, prior: 0.0).call

    expect(both.reload.data["register_mix"]).to(eq([1.0, nil, nil, nil, nil, nil, nil]))
    expect(only_press.reload.data).not_to(have_key("register_mix"))
  end

  it "ignores sources that illustrate the lexicon instead of sampling text" do
    described_class.new(io: StringIO.new, min_tokens: 3, prior: 0.0).call

    expect(both.reload.data["register_mix"][4]).to(be_nil)
    expect(both.data["register_n"]).to(eq(6))
  end

  it "pins a one-sided word to its own register" do
    described_class.new(io: StringIO.new, min_tokens: 3, prior: 0.0).call

    expect(only_talk.reload.data["register_mix"]).to(eq([1.0, nil, 0.0, nil, nil, nil, nil]))
    expect(only_press.reload.data["register_mix"]).to(eq([0.0, nil, 1.0, nil, nil, nil, nil]))
  end

  it "pulls a thin profile toward the flat prior" do
    described_class.new(io: StringIO.new, min_tokens: 3, prior: 12.0).call

    mix = only_talk.reload.data["register_mix"]
    expect(mix[0]).to(be_between(0.5, 0.75))
    expect(mix[0] + mix[2]).to(be_within(0.001).of(1.0))
  end

  it "builds a sentence profile out of the words that actually pick a side" do
    described_class.new(io: StringIO.new, min_tokens: 3, prior: 0.0).call

    expect(everywhere.reload.data["register_mix"]).to(eq([0.5, nil, 0.5, nil, nil, nil, nil]))
    mix = @probe.reload.data["register_mix"]
    expect(mix[0]).to(be > mix[2])
    expect(@probe.data["register_n"]).to(eq(1))
  end

  it "drops profiles that the sources no longer support" do
    stale = create(:lexeme, kind: :word, text: "戊")
    stale.update_column(:data, {"register_mix" => [1, 0, 0, 0, 0], "register_n" => 9, "tbcl_grade" => "1"})

    described_class.new(io: StringIO.new, min_tokens: 3, prior: 0.0).call

    expect(stale.reload.data).not_to(have_key("register_mix"))
    expect(stale.data["tbcl_grade"]).to(eq("1"))
  end
end
