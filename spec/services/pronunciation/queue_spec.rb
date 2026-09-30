# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Queue do
  let(:user) { create(:user) }

  def drills_allowing(*keys, available: true)
    instance_double(Pronunciation::Drills, available?: available, approved_keys: keys.to_set).tap do |drills|
      allow(drills).to(receive(:approves?)) { |key| keys.include?(key) }
    end
  end

  def word(text, pinyin, score: 100.0, freq: 1000, kind: :word)
    create(:lexeme, kind:, text:, readings: {"pinyin" => pinyin}, score:, data: {"freq_rank" => freq})
  end

  def clips(levels = {})
    Class.new { define_method(:quality) { |text, zhuyin: nil| levels.fetch(text, Huayu::MoeAudio::ABSENT) } }.new
  end

  def queue(drills:, collection: nil, audio: clips, catalog: Pronunciation::Catalog.new(drills:, audio:))
    described_class.new(user:, collection:, drills:, audio:, catalog:)
  end

  def practiced!(lexeme, key, overall: 96, level: "green")
    skill = SyllableSkill.claim(user, key)
    4.times { skill.record!(overall:, level:) }
    PronunciationAttempt.create!(
      user:,
      lexeme:,
      syllable_key: key,
      syllable_index: 0,
      ok: level == "green",
      level:,
      score_overall: overall
    )
  end

  describe "a beginner" do
    it "is never shown a syllable we recognize poorly" do
      good = word("巴", "bā", kind: :character, freq: 500)
      risky = word("罕", "hǎn", kind: :character, freq: 1)

      result = queue(drills: drills_allowing("ba1")).ids

      expect(result).to(eq([good.id]))
      expect(result).not_to(include(risky.id))
    end

    it "reads the syllable index once, however many syllables are approved" do
      word("巴", "bā", kind: :character, freq: 500)
      word("怕", "pà", kind: :character, freq: 400)
      allow(Pronunciation::SyllableIndex).to(receive(:for).and_call_original)

      queue(drills: drills_allowing("ba1", "pa4")).ids

      expect(Pronunciation::SyllableIndex).to(have_received(:for).once)
    end

    it "would rather show nothing than something it cannot grade" do
      word("罕", "hǎn", kind: :character)

      expect(queue(drills: drills_allowing("ba1")).ids).to(be_empty)
    end

    it "covers every tone, both halves of each aspiration pair and all three sibilant series" do
      carriers = {
        "巴" => %w[bā ba1],
        "怕" => %w[pà pa4],
        "大" => %w[dà da4],
        "他" => %w[tā ta1],
        "高" => %w[gāo gao1],
        "看" => %w[kàn kan4],
        "雞" => %w[jī ji1],
        "七" => %w[qī qi1],
        "西" => %w[xī xi1],
        "知" => %w[zhī zhi1],
        "吃" => %w[chī chi1],
        "十" => %w[shí shi2],
        "字" => %w[zì zi4],
        "詞" => %w[cí ci2],
        "四" => %w[sì si4],
        "馬" => %w[mǎ ma3]
      }
      carriers.each_with_index { |(text, (pinyin, _)), i| word(text, pinyin, kind: :character, freq: 900 - i) }

      result = queue(drills: drills_allowing(*carriers.values.map(&:last))).ids
      shown = Lexeme.where(id: result).flat_map { |l| Huayu::PronunciationTarget.new(l).syllables }
      initials = shown.filter_map { |syllable| Pronunciation::Parts.split(syllable["zhuyin"]).first }.uniq

      expect(shown.map { |syllable| syllable["tone"] }.uniq).to(include(1, 2, 3, 4))
      expect(initials).to(include("ㄅ", "ㄆ", "ㄉ", "ㄊ", "ㄍ", "ㄎ"))
      expect(initials).to(include("ㄓ", "ㄔ", "ㄕ"))
      expect(initials).to(include("ㄗ", "ㄘ", "ㄙ"))
      expect(initials).to(include("ㄐ", "ㄑ", "ㄒ"))
    end

    it "offers the most common material first" do
      word("低頻", "dīpín", score: 900.0, freq: 9000)
      common = word("常見", "chángjiàn", score: 2.0, freq: 3)

      result = queue(drills: drills_allowing("di1", "pin2", "chang2", "jian4")).ids

      expect(queue(drills: drills_allowing)).to(be_beginner)
      expect(result.first).to(eq(common.id))
    end
  end

  describe "a learner who has practiced" do
    it "does get the less reliable syllables, best material first" do
      done = word("巴巴", "bābā")
      measurable = word("常見", "chángjiàn", score: 500.0)
      risky = word("罕見", "hǎnjiàn", score: 1.0)
      practiced!(done, "ba1")

      result = queue(drills: drills_allowing("ba1", "chang2", "jian4")).ids

      expect(result).to(include(measurable.id, risky.id))
      expect(result.index(measurable.id)).to(be < result.index(risky.id))
    end

    it "puts a word with a weak syllable ahead of everything else" do
      weak = word("我們", "wǒmen", score: 500.0, freq: 8000)
      word("常見", "chángjiàn", score: 2.0, freq: 3)
      practiced!(weak, "wo3", overall: 35, level: "red")

      result = queue(drills: drills_allowing("wo3", "men5", "chang2", "jian4")).ids

      expect(queue(drills: drills_allowing)).not_to(be_beginner)
      expect(result.first).to(eq(weak.id))
    end

    it "leaves a syllable alone once it is reliably green" do
      good = word("我們", "wǒmen")
      practiced!(good, "wo3")

      expect(queue(drills: drills_allowing("wo3", "men5")).ids).not_to(include(good.id))
    end

    it "moves on to unstudied words by the dictionary rank" do
      done = word("巴巴", "bābā")
      easy = word("常見", "chángjiàn", score: 3.0)
      hard = word("罕見", "hǎnjiàn", score: 800.0)
      practiced!(done, "ba1")

      result = queue(drills: drills_allowing("ba1", "chang2", "jian4", "han3")).ids

      expect(result.index(easy.id)).to(be < result.index(hard.id))
    end
  end

  describe "the reference recording" do
    it "starts with words that have a clean one, then a noisy one, then none" do
      done = word("巴巴", "bābā")
      silent = word("常見", "chángjiàn", score: 1.0)
      noisy = word("罕見", "hǎnjiàn", score: 2.0)
      clean = word("看見", "kànjiàn", score: 900.0)
      practiced!(done, "ba1")
      audio = clips("看見" => Huayu::MoeAudio::CLEAN, "罕見" => Huayu::MoeAudio::AUDIBLE)

      result = queue(drills: drills_allowing("ba1", "chang2", "han3", "kan4", "jian4"), audio:).ids

      expect(result).to(eq([clean.id, noisy.id, silent.id]))
    end
  end

  describe "the catalog of ready words" do
    it "fills the queue from it without touching the dictionary, skipping what was already practiced" do
      done = word("巴巴", "bābā")
      practiced!(done, "ba1")
      groups = Pronunciation::Queue::HARD.map(&:first)
      entries = Array.new(40) { |i|
        {id: 9000 + i, audio: Huayu::MoeAudio::CLEAN, features: [groups[i % groups.size], "s:k#{i}"]}
      }
      catalog = instance_double(
        Pronunciation::Catalog,
        entries: [{id: done.id, audio: 0, features: ["s:ba1"]}, *entries]
      )

      result = queue(drills: drills_allowing("ba1"), catalog:).ids

      expect(result.size).to(eq(described_class::SIZE))
      expect(result).to(all(be >= 9000))
      expect(result.first(groups.size).map { |id| groups[(id - 9000) % groups.size] }).to(match_array(groups))
    end
  end

  describe "hard sounds" do
    it "walks through them instead of staying on the commonest one" do
      done = word("巴巴", "bābā")
      practiced!(done, "ba1")
      retroflex = [%w[知識 zhīshì], %w[事實 shìshí], %w[指示 zhǐshì], %w[吃食 chīshí]].each_with_index.map { |
          (text, pinyin),
          i
        |
        word(text, pinyin, score: i + 1.0)
      }
      others = [%w[積極 jījí], %w[語句 yǔjù], %w[自私 zìsī], %w[本能 běnnéng]].each_with_index.map { |
          (text, pinyin),
          i
        |
        word(text, pinyin, score: i + 10.0)
      }
      keys = %w[ba1 zhi1 shi4 shi2 zhi3 chi1 ji1 ji2 yu3 ju4 zi4 si1 ben3 neng2]

      result = queue(drills: drills_allowing(*keys)).ids

      expect(result.first(5)).to(contain_exactly(retroflex.first.id, *others.map(&:id)))
    end
  end

  describe "a collection" do
    it "never leaves it" do
      inside = word("常見", "chángjiàn")
      outside = word("罕見", "hǎnjiàn", score: 1.0)
      deck = Collection.create!(user:, name: "Моё", kind: :manual, position: 1)
      CollectionItem.create!(collection: deck, lexeme: inside, position: 0)

      result = queue(drills: drills_allowing("chang2", "jian4", "han3"), collection: deck).ids

      expect(result).to(eq([inside.id]))
      expect(result).not_to(include(outside.id))
    end
  end

  describe "variety" do
    it "breaks up a run of words sharing an initial" do
      %w[巴 波 比 嘎].each_with_index { |text, i|
        word(text, %w[bā bō bǐ gā][i], kind: :character, freq: i + 1)
      }
      other = Lexeme.find_by(text: "嘎")

      result = queue(drills: drills_allowing("ba1", "bo1", "bi3", "ga1")).ids

      expect(result.length).to(eq(4))
      expect(result.index(other.id)).to(be < 3)
    end
  end
end
