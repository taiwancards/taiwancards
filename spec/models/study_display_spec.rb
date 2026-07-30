# frozen_string_literal: true

require "rails_helper"

RSpec.describe StudyDisplay do
  it "uses stored defaults when params are empty" do
    Setting.instance.update_study_display!("front" => "reading", "reading" => "pinyin", "examples" => false)

    display = described_class.resolve(ActionController::Parameters.new)
    expect(display.front).to(eq("reading"))
    expect(display.reading).to(eq("pinyin"))
    expect(display.examples?).to(be(false))
  end

  it "lets params override defaults and rejects unknown modes" do
    display = described_class.resolve(
      ActionController::Parameters.new(front: "bogus", reading: "pinyin", examples: "0")
    )
    expect(display.front).to(eq("target"))
    expect(display.reading).to(eq("pinyin"))
    expect(display.examples?).to(be(false))
  end

  it "round-trips through params" do
    display = described_class.new(front: "reading", reading: "pinyin", examples: false)
    expect(display.to_params).to(eq({front: "reading", reading: "pinyin", examples: "0"}))
  end
end
