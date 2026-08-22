# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Phrases do
  let(:user) { create(:user) }

  let(:source) do
    ContentSource.create!(
      slug: "phrases_src",
      license_commercial: true,
      name: "Test",
      enabled: true,
      enabled_for_admins: true,
      attribution: "Test source."
    )
  end

  def sentence(text, segments)
    line = Lexeme.new(kind: :sentence, text:, data: {"segments" => segments})
    line.lexeme_content_sources.build(content_source: source)
    line.save!
    line
  end

  def word(text, pinyin, kind: :word)
    create(:lexeme, kind:, text:, readings: {"pinyin" => pinyin})
  end

  def phrases(rows)
    described_class.new.tap { |set| allow(set).to(receive(:rows).and_return(rows)) }
  end

  it "offers only what the learner's level reaches" do
    easy = sentence("我們吃飯吧", %w[我們 吃飯 吧])
    hard = sentence("我覺得不太對勁", %w[我 覺得 不 太 對勁])
    set = phrases([{"text" => easy.text, "level" => 1}, {"text" => hard.text, "level" => 6}])

    expect(set.ids_up_to(1)).to(eq([easy.id]))
    expect(set.ids_up_to(6)).to(contain_exactly(easy.id, hard.id))
  end

  it "keeps a beginner on the first level" do
    user.level = "zero"
    expect(described_class.new.level_for(user)).to(eq(described_class::BEGINNER_LEVEL))
  end

  it "follows the learner's grade once they have one" do
    user.level = "4"
    expect(described_class.new.level_for(user)).to(eq(4))
  end

  it "spells a sentence out of the words it was segmented into" do
    word("我們", "wǒmen")
    word("吃飯", "chīfàn")
    word("吧", "ba")
    line = sentence("我們吃飯吧", %w[我們 吃飯 吧])

    rows = Huayu::PronunciationTarget.new(line).syllables
    expect(rows.map { |row| row["char"] }).to(eq(%w[我 們 吃 飯 吧]))
    expect(rows.map { |row| row["key"] }).to(eq(%w[wo3 men5 chi1 fan4 ba5]))
  end

  it "spells nothing when a word of the sentence has no reading" do
    word("我們", "wǒmen")
    line = sentence("我們吃飯吧", %w[我們 吃飯 吧])

    expect(Huayu::PronunciationTarget.new(line).syllables).to(be_empty)
  end

  describe "in the queue" do
    it "weaves phrases in among the words" do
      words = Array.new(12) { |i| create(:lexeme, kind: :word, text: "詞#{i}", readings: {"pinyin" => "cí"}) }
      line = sentence("我們吃飯吧", %w[我們 吃飯 吧])
      set = phrases([{"text" => line.text, "level" => 1}])
      drills = instance_double(Pronunciation::Drills, available?: false)

      ids = described_class::BEGINNER_LEVEL.then do
        Pronunciation::Queue.new(user:, drills:, phrases: set).ids
      end

      expect(ids).to(include(line.id))
      expect(ids.count(line.id)).to(eq(1))
      expect(ids & words.map(&:id)).to(be_present)
    end

    it "leaves a collection run to its own words" do
      create(:lexeme, kind: :word, text: "詞", readings: {"pinyin" => "cí"})
      line = sentence("我們吃飯吧", %w[我們 吃飯 吧])
      set = phrases([{"text" => line.text, "level" => 1}])
      collection = Collection.create!(kind: :manual, name: "Deck", user:)
      drills = instance_double(Pronunciation::Drills, available?: false)

      ids = Pronunciation::Queue.new(user:, collection:, drills:, phrases: set).ids
      expect(ids).not_to(include(line.id))
    end
  end
end
