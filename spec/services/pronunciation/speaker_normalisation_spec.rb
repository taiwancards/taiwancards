# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Vowel do
  it "measures the vowel against the speaker's own pitch" do
    features = {"f1_vowel" => 600.0, "f1_onset" => 500.0, "f0_ref_hz" => 200.0}

    expect(described_class.place(features, 100.0).values_at("f1_over_f0", "f1_onset_over_f0")).to(eq([6.0, 5.0]))
  end

  it "falls back to the syllable's own pitch when the speaker is unknown" do
    features = {"f1_vowel" => 600.0, "f0_ref_hz" => 200.0}

    expect(described_class.place(features, nil)["f1_over_f0"]).to(eq(3.0))
  end

  it "leaves the measurement out when there is no usable pitch at all" do
    features = {"f1_vowel" => 600.0, "f0_ref_hz" => 0.0}

    expect(described_class.place(features, nil)).not_to(have_key("f1_over_f0"))
  end

  it "trusts the pitch reference for a voice inside the corpus range" do
    features = {"f1_vowel" => 600.0, "f0_ref_hz" => 220.0}

    expect(described_class.place(features, 220.0)["pitch_referenced"]).to(be(true))
  end

  it "refuses the pitch reference for a voice far below every corpus speaker" do
    features = {"f1_vowel" => 800.0, "f0_ref_hz" => 124.0}

    expect(described_class.place(features, 124.0)["pitch_referenced"]).to(be(false))
  end

  it "takes the speaker's pitch as the median over the utterance" do
    rows = [{"f0_ref_hz" => 180.0}, {"f0_ref_hz" => 200.0}, {"f0_ref_hz" => 260.0}]

    expect(described_class.speaker_hz(rows)).to(eq(200.0))
  end

  it "ignores unvoiced syllables when taking the speaker's pitch" do
    rows = [{"f0_ref_hz" => 0.0}, {"f0_ref_hz" => 200.0}, {"f0_ref_hz" => 220.0}]

    expect(described_class.speaker_hz(rows)).to(eq(210.0))
  end
end

RSpec.describe Pronunciation::Acoustic::Timbre do
  def frames(value) = Array.new(3) { Array.new(2, value) }

  it "shifts a speaker's cepstra onto the reference average" do
    pairs = Array.new(3) { [frames(1.0), frames(3.0)] }
    described_class.align(pairs)

    expect(pairs.map(&:first)).to(all(eq(frames(3.0))))
  end

  it "keeps the differences between syllables intact" do
    pairs = [[frames(1.0), frames(2.0)], [frames(2.0), frames(2.0)], [frames(3.0), frames(2.0)]]
    described_class.align(pairs)
    spoken = pairs.map { |mine, _| mine.first.first }

    expect(spoken[2] - spoken[0]).to(eq(2.0))
  end

  it "does nothing when the utterance is too short to estimate a mean" do
    pairs = [[frames(1.0), frames(5.0)], [frames(1.0), frames(5.0)]]
    described_class.align(pairs)

    expect(pairs.map(&:first)).to(all(eq(frames(1.0))))
  end

  it "skips syllables whose template is missing" do
    pairs = [[frames(1.0), nil], [frames(1.0), frames(3.0)], [frames(1.0), frames(3.0)]]
    described_class.align(pairs)

    expect(pairs.first.first).to(eq(frames(1.0)))
  end
end

RSpec.describe Pronunciation::Acoustic::Features do
  let(:glide_then_nucleus) { ([300.0] * 5) + ([900.0] * 10) + ([320.0] * 5) }

  it "reads the nucleus of a rime that opens with a medial, not the medial itself" do
    expect(described_class.span_median(glide_then_nucleus, described_class::VOWEL_SPAN)).to(eq(900.0))
  end

  it "reads the medial from the early window of the same rime" do
    expect(described_class.span_median(glide_then_nucleus, described_class::GLIDE_SPAN)).to(eq(300.0))
  end

  it "ignores dropped frames inside the window" do
    track = ([300.0] * 5) + [0.0, 0.0, 910.0, 910.0, 910.0, 0.0, 0.0, 910.0, 910.0, 910.0] + ([320.0] * 5)

    expect(described_class.span_median(track, described_class::VOWEL_SPAN)).to(eq(910.0))
  end

  it "reads a rime closed by a nasal before the murmur starts" do
    rime = ([300.0] * 5) + ([900.0] * 8) + ([340.0] * 7)

    expect(described_class.span_median(rime, described_class.nucleus_span(true))).to(eq(900.0))
  end

  it "reads an open rime later, where a medial has already given way to the nucleus" do
    expect(described_class.nucleus_span(false).end).to(be > described_class.nucleus_span(true).end)
  end

  it "falls back to nothing when every frame of the window was dropped" do
    expect(described_class.span_median(Array.new(20, 0.0), described_class::VOWEL_SPAN)).to(be_nil)
  end
end

RSpec.describe Pronunciation::TemplateStore do
  it "reads a lone syllable against the citation reference" do
    expect(described_class.instance.norm_for(position: 0, total: 1)).to(eq(described_class::CITATION))
  end

  it "reads every syllable of a longer item against the pooled word reference" do
    positions = (0..4).map { |i| described_class.instance.norm_for(position: i, total: 5) }

    expect(positions.uniq).to(eq([described_class::WORD]))
  end
end

RSpec.describe Pronunciation::Acoustic::Phonology do
  it "marks the empty rime after the dental sibilants" do
    expect(%w[zi ci si].map { |s| described_class.analyze(s)[:apical] }).to(all(eq(:dental)))
  end

  it "marks the empty rime after the retroflex series" do
    expect(%w[zhi chi shi ri].map { |s| described_class.analyze(s)[:apical] }).to(all(eq(:retroflex)))
  end

  it "leaves a real close front vowel alone" do
    expect(%w[ji qi xi bi di li yi].map { |s| described_class.analyze(s)[:apical] }).to(all(be_nil))
  end

  it "gives the Taiwan glottal value for h" do
    expect(described_class.analyze("hao")[:initial_ipa]).to(eq("h"))
  end
end

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:analyzer) { described_class.new(Pronunciation::TemplateStore.instance) }

  it "measures the vowel against the voice when the pitch reference holds" do
    expect(analyzer.vowel_pair({"pitch_referenced" => true}).first).to(eq("f1_over_f0"))
    expect(analyzer.vowel_fields({"pitch_referenced" => true})).to(include("f1_over_f0"))
  end

  it "falls back to the tract's own ratios when the pitch reference does not hold" do
    expect(analyzer.vowel_pair({"pitch_referenced" => false}).first).to(eq("f1_ratio"))
    expect(analyzer.vowel_fields({"pitch_referenced" => false})).not_to(include("f1_over_f0"))
  end

  it "keeps frontness on a within-tract ratio either way" do
    expect(analyzer.vowel_pair({"pitch_referenced" => true}).last).to(eq("f2_over_f1"))
    expect(analyzer.vowel_pair({"pitch_referenced" => false}).last).to(eq("f2_over_f1"))
  end
end

RSpec.describe VoiceProfile do
  def profile(f3:, hz:)
    described_class.new(f3_ref: f3).tap { |v| allow(v).to(receive(:f0_median).and_return(hz)) }
  end

  it "keeps a third formant that agrees with the voice's pitch" do
    expect(profile(f3: 3300.0, hz: 230.0).trusted_f3).to(eq(3300.0))
  end

  it "drops a third formant that contradicts the voice's pitch" do
    voice = profile(f3: 3654.0, hz: 124.0)

    expect(voice.f3_disagrees?).to(be(true))
    expect(voice.trusted_f3).to(eq(described_class::FALLBACK_F3["male"]))
  end

  it "does not stretch the analysis to a tract the pitch says is not there" do
    expect(profile(f3: 3654.0, hz: 124.0).warp).to(be < profile(f3: 3654.0, hz: 230.0).warp)
  end
end

RSpec.describe Pronunciation::Acoustic::Features do
  it "leaves the pitch floor where it is for a voice that never goes near it" do
    expect(described_class.floor_for(190.0)).to(eq(DSP::Yin::DEFAULT_MINIMUM_HZ))
  end

  it "reaches below the default for a voice that lives down there" do
    floor = described_class.floor_for(81.0)

    expect(floor).to(be < DSP::Yin::DEFAULT_MINIMUM_HZ)
    expect(floor).to(be > described_class::PITCH_FLOOR.min - 0.01)
  end

  it "never chases a pitch nobody has" do
    expect(described_class.floor_for(40.0)).to(eq(described_class::PITCH_FLOOR.min))
  end

  it "asks for nothing when the voice is unknown" do
    expect(described_class.floor_for(nil)).to(be_nil)
  end
end

RSpec.describe Pronunciation::AcousticBackend do
  let(:voice) do
    VoiceProfile.new(f3_ref: 2650.0, calibrated_at: Time.current).tap do |v|
      allow(v).to(receive(:reference_hz).and_return(124.0))
      allow(v).to(receive(:tone_anchor)) { |tone| {1 => 140.0, 2 => 120.0, 3 => 96.0, 4 => 130.0}[tone] }
    end
  end

  let(:backend) { described_class.new(voice:) }

  it "measures the voice with the tract the warmup found, not one guessed per clip" do
    expect(backend.send(:speaker_f3)).to(eq(voice.trusted_f3))
    expect(described_class.new.send(:speaker_f3)).to(be_nil)
  end

  it "measures a low tone against the pitch that tone actually sits at" do
    expect(backend.send(:tone_reference_hz, 3)).to(eq(96.0))
    expect(backend.send(:tone_reference_hz, 1)).to(eq(140.0))
  end

  it "leaves a genuinely low third tone alone instead of doubling it" do
    curve = Array.new(6, 70.0)

    expect(Pronunciation::Acoustic::Features.octave_aligned(curve, 96.0)).to(eq(curve))
    expect(Pronunciation::Acoustic::Features.octave_aligned(curve, 124.0).first).to(be > 100.0)
  end

  it "still catches a reading that came back an octave low" do
    curve = Array.new(6, 48.0)

    expect(Pronunciation::Acoustic::Features.octave_aligned(curve, 96.0).first).to(eq(96.0))
  end
end
