# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::CardSet do
  let(:user) { create(:user) }

  def ids_of(tokens) = tokens.map { |token| token.split(":").first.to_i }.uniq

  def word(text, freq_rank)
    create(:lexeme, kind: :word, text:, data: {"freq_rank" => freq_rank})
  end

  describe "today mode" do
    def tocfl(name, tag, position, words)
      Collection.create!(kind: :tocfl, name:, level_tag: tag, position:).tap do |collection|
        collection.add_lexemes(words.map(&:id))
      end
    end

    it "draws new cards from the plan's TOCFL scope at the plan's daily quota" do
      novice = Array.new(3) { |i| word("初#{i}", 100 + i) }
      band_a = Array.new(2) { |i| word("甲#{i}", 200 + i) }
      beyond = word("乙", 300)
      frequent = word("常", 1)
      tocfl("TOCFL Novice 1", "Novice1", 0, novice)
      tocfl("TOCFL Band A · A1", "A1", 2, band_a)
      tocfl("TOCFL Band B · B1", "B1", 4, [beyond])
      StudyPlan.create!(user:, target_level: "A1", target_date: 2.days.from_now.to_date)

      picked = ids_of(described_class.new(user:).build(mode: "today"))

      expect(picked.size).to(eq(3))
      expect(picked).to(all(be_in((novice + band_a).map(&:id))))
      expect(picked).not_to(include(beyond.id, frequent.id))
      expect(LexemeMemory.active.owned_by(user).distinct.pluck(:lexeme_id)).to(match_array(picked))
    end

    it "falls back to the session size and the frequency pool without a plan" do
      words = Array.new(4) { |i| word("詞#{i}", i + 1) }

      picked = ids_of(described_class.new(user:).build(mode: "today"))

      expect(picked).to(match_array(words.map(&:id)))
    end
  end

  describe "mistakes mode" do
    def reviewed!(lexeme, rating:, at:)
      memory = LexemeMemory.find_or_create_by!(user:, lexeme:, facet: "recognition") { |fresh|
        fresh.activated_at = at
      }
      LexemeReview.create!(user:, lexeme:, lexeme_memory: memory, facet: "recognition", rating:, reviewed_at: at)
    end

    it "revisits what was rated again during the last week, newest first, and nothing else" do
      slipped = word("滑", 10)
      twice = word("再", 20)
      fine = word("好", 30)
      stale = word("舊", 40)
      reviewed!(twice, rating: Fsrs::Scheduler::RATINGS[:again], at: 3.days.ago)
      reviewed!(slipped, rating: Fsrs::Scheduler::RATINGS[:again], at: 1.day.ago)
      reviewed!(fine, rating: Fsrs::Scheduler::RATINGS[:good], at: 1.day.ago)
      reviewed!(stale, rating: Fsrs::Scheduler::RATINGS[:again], at: 10.days.ago)

      expect(described_class.new(user:).select(mode: "mistakes")).to(eq([slipped.id, twice.id]))
    end
  end
end
