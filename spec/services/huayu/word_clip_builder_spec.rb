# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::WordClipBuilder do
  subject(:builder) { described_class.new(words: [], out: Pathname(Dir.mktmpdir), log: StringIO.new) }

  def source(text, segments = nil)
    lexeme = segments && build(:lexeme, kind: :sentence, text:, data: {"segments" => segments})
    described_class::Source.new(text:, path: "#{text}.wav", lexeme:)
  end

  it "prefers the word said on its own, then as a whole word at the end of a phrase" do
    allow(builder).to(
      receive(:sources).and_return(
        [
          source("謝謝國文老師", %w[謝謝 國文 老師]),
          source("淑芬加一謝謝", %w[淑芬 加一 謝謝]),
          source("謝謝"),
          source("多謝謝你", %w[多謝 謝你])
        ]
      )
    )

    expect(builder.send(:sources_for, "謝謝").map(&:text)).to(
      eq(%w[謝謝 淑芬加一謝謝 謝謝國文老師 多謝謝你])
    )
  end

  it "cuts a word inside a phrase exactly at its neighbors and pads only the free edges" do
    spans = [[0, 200], [210, 400], [410, 600], [610, 800]]

    expect(builder.send(:window, spans, 1, 2)).to(eq([200, 600]))
    expect(builder.send(:window, spans, 2, 3)).to(eq([400, 800 + described_class::PAD_AFTER_MS]))
    expect(builder.send(:window, spans, 0, 1)).to(eq([0, 400]))
  end
end
