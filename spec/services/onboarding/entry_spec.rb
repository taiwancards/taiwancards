# frozen_string_literal: true

require "rails_helper"

RSpec.describe Onboarding::Entry do
  def user_with(prefs) = build(:user, prefs:)

  def step(user, door: nil) = described_class.new(user:, door:).step

  describe "#step" do
    it "asks a guest to sign in, whatever is waiting" do
      expect(step(nil)).to(eq(:sign_in))
      expect(step(nil, door: "words")).to(eq(:sign_in))
    end

    it "asks a newcomer from a door whose language is not settled for it first" do
      newcomer = user_with("entry_door" => "words", "goal" => "classes")

      expect(step(newcomer, door: "words")).to(eq(:language))
    end

    it "goes straight to the door once the language is known" do
      newcomer = user_with("entry_door" => "text", "language_chosen" => true)

      expect(step(newcomer, door: "text")).to(eq(:door))
    end

    it "takes an account that predates the doors through a door without asking the language" do
      settled = user_with("goal" => "guided")
      undecided = user_with({})

      expect(step(settled, door: "exam")).to(eq(:door))
      expect(step(undecided, door: "lookup")).to(eq(:door))
    end

    it "still puts the questionnaire in front of a newcomer with no door behind them" do
      expect(step(user_with({}))).to(eq(:questionnaire))
      expect(step(user_with("language_chosen" => true))).to(eq(:questionnaire))
    end

    it "lets a newcomer who came through a door skip the questionnaire, goal or not" do
      expect(step(user_with("entry_door" => "lookup", "language_chosen" => true))).to(eq(:home))
      expect(step(user_with("entry_door" => "exam", "goal" => "tocfl"))).to(eq(:home))
    end

    it "sends an onboarded account home" do
      expect(step(user_with("goal" => "classes"))).to(eq(:home))
    end

    it "ignores a door it does not know" do
      expect(described_class.new(user: user_with("goal" => "tocfl"), door: "admin").door).to(be_nil)
      expect(step(user_with("goal" => "tocfl"), door: "admin")).to(eq(:home))
    end

    it "only ever answers with one of its steps" do
      users = [nil, user_with({}), user_with("goal" => "tocfl"), user_with("entry_door" => "words")]
      doors = [nil, *described_class::DOORS]

      steps = users.product(doors).map { |user, door| step(user, door:) }

      expect(steps.to_set).to(be_subset(described_class::STEPS.to_set))
    end
  end

  describe "#offer_setup?" do
    it "offers the optional setup to a door newcomer until the level is chosen" do
      expect(described_class.new(user: user_with("entry_door" => "text")).offer_setup?).to(be(true))
      expect(described_class.new(user: user_with("entry_door" => "text", "start_level" => "zero")).offer_setup?).to(
        be(false)
      )
    end

    it "leaves everyone else to the usual flow" do
      expect(described_class.new(user: user_with({})).offer_setup?).to(be(false))
      expect(described_class.new(user: nil).offer_setup?).to(be(false))
    end
  end

  describe ".admit" do
    it "infers the goal from the door and settles the language when the page answered it" do
      exam = described_class.admit(create(:user, :new_arrival), door: "exam", language_settled: true)
      words = described_class.admit(create(:user, :new_arrival), door: "words", language_settled: false)

      expect(exam.reload.prefs).to(include("entry_door" => "exam", "goal" => "tocfl", "language_chosen" => true))
      expect(words.reload.prefs).to(include("entry_door" => "words", "goal" => "classes"))
      expect(words.prefs).not_to(have_key("language_chosen"))
    end

    it "gives a reader or a dictionary newcomer no goal yet" do
      text = described_class.admit(create(:user, :new_arrival), door: "text", language_settled: true)
      lookup = described_class.admit(create(:user, :new_arrival), door: "lookup", language_settled: true)

      expect([text.reload.goal, lookup.reload.goal]).to(eq([nil, nil]))
      expect([text.entry_door, lookup.entry_door]).to(eq(%w[text lookup]))
    end

    it "leaves an account alone when there was no door" do
      user = create(:user, :new_arrival)

      described_class.admit(user, door: nil, language_settled: true)

      expect(user.reload.prefs).to(eq({}))
    end
  end

  describe ".door_behind" do
    it "reads the door from the page a sign-in returns to" do
      expect(described_class.door_behind("/ru/doors/words/continue")).to(eq("words"))
      expect(described_class.door_behind("/en/doors/lookup/continue?q=xuexiao")).to(eq("lookup"))
      expect(described_class.door_behind("/en/doors/exam/continue?paper=a-set1-reading")).to(eq("exam"))
      expect(described_class.door_behind("/vi/exams")).to(eq("exam"))
      expect(described_class.door_behind("/en/doors/text")).to(eq("text"))
    end

    it "finds no door behind other pages, foreign addresses or nothing" do
      expect(described_class.door_behind("/en/dict/學校")).to(be_nil)
      expect(described_class.door_behind("/en/desk")).to(be_nil)
      expect(described_class.door_behind("/nowhere/at/all")).to(be_nil)
      expect(described_class.door_behind(nil)).to(be_nil)
    end
  end
end
