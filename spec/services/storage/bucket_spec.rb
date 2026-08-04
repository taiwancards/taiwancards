# frozen_string_literal: true

require "rails_helper"

RSpec.describe Storage::Bucket do
  let(:name) { "B1L01-I-01.mp3" }

  before { TextbookLesson.forget_audio_names! }

  after { TextbookLesson.forget_audio_names! }

  it "prefers a clip that is already on this machine" do
    allow(TextbookLesson).to(receive(:audio_path).and_return(Rails.root.join("Gemfile")))

    kind, = TextbookLesson.audio_source(name)

    expect(kind).to(eq(:file))
  end

  it "signs a link when the clip only lives in the bucket" do
    allow(TextbookLesson).to(receive(:audio_path).and_return(nil))
    allow(described_class).to(receive(:configured?).and_return(true))
    allow(TextbookLesson).to(receive(:audio_names).and_return(Set[name]))
    allow(described_class).to(receive(:runtime).and_return(instance_double(described_class, link: "https://r2/x")))

    expect(TextbookLesson.audio_source(name)).to(eq([:link, "https://r2/x"]))
  end

  it "refuses to sign a link for a clip nobody has" do
    allow(TextbookLesson).to(receive(:audio_path).and_return(nil))
    allow(described_class).to(receive(:configured?).and_return(true))
    allow(TextbookLesson).to(receive(:audio_names).and_return(Set.new))

    expect(TextbookLesson.audio_source(name)).to(be_nil)
  end

  it "refuses a name that is not a clip at all" do
    expect(TextbookLesson.audio_source("../config/database.yml")).to(be_nil)
  end

  it "reports itself unconfigured when the credentials are missing" do
    allow(ENV).to(receive(:fetch).and_call_original)
    allow(ENV).to(receive(:fetch).with("R2_ACCESS_KEY_ID", nil).and_return(nil))

    expect(described_class).not_to(be_configured)
  end
end
