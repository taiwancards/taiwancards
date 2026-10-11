# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Starter lessons" do
  let(:track) do
    {
      "lessons" => [
        {
          "slug" => "hello",
          "title" => {"en" => "Hello", "ru" => "Привет"},
          "symbols" => %w[ㄋ ㄧ ㄏ ㄠ],
          "words" => [
            {"zh" => "你", "en" => "you"},
            {"zh" => "好", "en" => "good"},
            {"zh" => "你好", "en" => "hello"}
          ],
          "capsule" => {"en" => "Third tone dips.", "ru" => "Третий тон ныряет."},
          "phrase" => {"zh" => "你好！", "zhuyin" => "ㄋㄧˇ ㄏㄠˇ", "en" => "Hello!", "ru" => "Привет!"}
        },
        {
          "slug" => "goodbye",
          "title" => {"en" => "Goodbye", "ru" => "Пока"},
          "symbols" => %w[ㄗ ㄞ ㄐ ㄢ],
          "words" => [{"zh" => "再見", "en" => "goodbye"}],
          "capsule" => {},
          "phrase" => nil
        },
        {
          "slug" => "again",
          "title" => {"en" => "Again", "ru" => "Снова"},
          "symbols" => [],
          "words" => [{"zh" => "你好", "en" => "hello"}],
          "capsule" => {},
          "phrase" => nil
        }
      ]
    }
  end

  let(:user) { sign_in(create(:user, prefs: {"goal" => "guided", "start_level" => "zero"})) }

  let!(:words) do
    {
      "你" => create(
        :lexeme,
        kind: :character,
        text: "你",
        readings: {"pinyin" => "nǐ", "zhuyin" => "ㄋㄧˇ"},
        meanings: {"en" => "you"}
      ),
      "好" => create(
        :lexeme,
        kind: :character,
        text: "好",
        readings: {"pinyin" => "hǎo", "zhuyin" => "ㄏㄠˇ"},
        meanings: {"en" => "good"}
      ),
      "你好" => create(
        :lexeme,
        kind: :word,
        text: "你好",
        readings: {"pinyin" => "nǐ hǎo", "zhuyin" => "ㄋㄧˇ ㄏㄠˇ"},
        meanings: {"en" => "hello"}
      )
    }
  end

  before do
    Huayu::StarterTrack.reset!
    allow(Huayu::StarterTrack::DATA).to(receive(:value).and_return(track))
  end

  it "plays the lesson as symbols, a capsule, words and a phrase" do
    user
    get("/starter/hello")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(
      include("data-controller=\"starter-lesson\"", "/zhuyin/ㄋ.opus", "Third tone dips.", "Hello!")
    )
    expect(response.body.scan("data-starter-lesson-target=\"step\"").size).to(eq(4 + 4 + 1 + 3 + 3 + 1 + 1))
  end

  it "explains each tone on its own and says the word the way it is spoken" do
    user
    get("/starter/hello")

    expect(response.body).to(include("Third tone: low", "Two third tones in a row", "ㄋㄧˊ ㄏㄠˇ"))
    expect(response.body.scan(/data-card-speech-target="syllable".*?<\/div>/m).last).to(include("ㄏㄠˇ"))
    expect(response.body).to(include("data-card-speech-silence-ms-value"))
  end

  it "grades the words, keeps the symbols and fills the first deck" do
    user
    post(
      "/starter/hello",
      params: {
        symbols: {"ㄋ" => true, "ㄠ" => false}.to_json,
        words: {words["你"].id => true, words["好"].id => false}.to_json
      }
    )

    expect(response).to(redirect_to("/en/starter/hello/done"))
    expect(CourseCompletion.find_by(user:, slug: "starter:hello")).to(have_attributes(score: 1, total: 2))
    expect(user.reload.zhuyin_mastery.keys).to(include("ㄋ", "ㄠ"))
    deck = Collection.desks_for(user).find_by(name: "First words")
    expect(deck.collection_items.pluck(:lexeme_id)).to(contain_exactly(words["你"].id, words["好"].id))
    expect(LexemeMemory.find_by(user:, lexeme: words["你"], facet: :recognition)).not_to(be_state_unseen)

    follow_redirect!
    expect(response.body).to(include("Lesson complete", "Next: Goodbye"))
  end

  it "brings back the learner's weakest symbols once a lesson has no new ones" do
    strong = {"streak" => 5, "seen" => 5, "correct" => 5}
    mastery = %w[ㄋ ㄧ ㄏ ㄠ ㄗ ㄞ ㄐ ㄢ].to_h { |symbol| [symbol, strong] }
    user.update!(
      prefs: user.prefs.merge("zhuyin_mastery" => mastery.merge("ㄏ" => {"streak" => 0, "seen" => 4, "correct" => 1}))
    )

    get("/starter/again")

    expect(response.body).to(include("data-subject=\"ㄏ\""))
    expect(response.body.scan(/data-group="symbols" data-subject="(\S+)"/).flatten.uniq.size).to(
      eq(StarterLessonsController::REFRESH)
    )
  end

  it "leaves out a learner who already studies plenty of cards" do
    learner = create(:user, prefs: {"goal" => "guided", "start_level" => "phonetics", "level" => "phonetics"})
    Learn::Starter::FRESH_CARDS.times do |index|
      word = create(:lexeme, kind: :word, text: "詞#{index}")
      LexemeMemory.create!(
        user: learner,
        lexeme: word,
        facet: :recognition,
        state: :review,
        due_at: 1.day.from_now,
        activated_at: 1.week.ago
      )
    end

    expect(Learn::Starter.new(learner)).not_to(be_active)
  end

  it "makes the next lesson the next step for a beginner and leaves experienced learners alone" do
    expect(Learn::NextStep.new(user).call).to(have_attributes(kind: "starter", subject: "hello"))

    expert = create(:user, prefs: {"goal" => "guided", "start_level" => "experienced", "level" => "3"})
    expect(Learn::NextStep.new(expert).call.kind).not_to(eq("starter"))
  end

  it "puts the lesson on a beginner's home screen" do
    user
    get("/desk")

    expect(response.body).to(include("First steps · lesson 1 of 3", "/starter/hello"))
    expect(Nokogiri::HTML(response.body).at_css("#desk-start")["href"]).to(eq("/en/starter/hello"))
  end
end
