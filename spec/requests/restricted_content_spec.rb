# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Restricted content gating" do
  let!(:phrase) { create(:lexeme, kind: :phrase, text: "測試句子", restricted: true) }

  it "excludes restricted lexemes from Lexeme.visible_to unless the user has access" do
    expect(Lexeme.visible_to(create(:user))).not_to(include(phrase))
    expect(Lexeme.visible_to(create(:user, restricted_content: true))).to(include(phrase))
  end

  it "honors an admin who has switched restricted content off for themselves" do
    admin = create(:user, :admin, restricted_content: false)

    expect(Lexeme.visible_to(admin)).not_to(include(phrase))
    expect(Lexemes::Search.new(user: admin).call("測試句子").map(&:lexeme)).not_to(include(phrase))
  end

  it "never surfaces phrases in the top search, whatever the user's access" do
    reader = create(:user)
    keeper = create(:user, restricted_content: true)

    expect(Lexemes::Search.new(user: reader).call("測試句子").map(&:lexeme)).not_to(include(phrase))
    expect(Lexemes::Search.new(user: keeper).call("測試句子").map(&:lexeme)).not_to(include(phrase))
  end

  it "still finds words and characters" do
    word = create(:lexeme, kind: :word, text: "測試", meanings: {"en" => "test"})

    expect(Lexemes::Search.new(user: create(:user)).call("測試").map(&:lexeme)).to(include(word))
  end

  it "redirects a user without restricted access away from the Textbook section" do
    get(textbook_path)
    expect(response).to(redirect_to(root_path))
  end

  it "keeps a restricted sentence out of the sentence search unless the user has access" do
    source = ContentSource.create!(
      slug: "probe",
      license_commercial: true,
      name: "Probe",
      register: :colloquial,
      enabled: true,
      attribution: "probe"
    )
    sentence = create(
      :lexeme,
      kind: :sentence,
      text: "這是測試句子。",
      restricted: true,
      data: {"segments" => ["測試"]},
      content_sources: [source]
    )
    SentenceProfile.create!(lexeme: sentence, source_ids: [source.id])

    expect(concordance_for(create(:user))).not_to(include(sentence))
    expect(concordance_for(create(:user, restricted_content: true))).to(include(sentence))
  end

  def concordance_for(user)
    Search::Concordance.new(user:).call(groups: [["測試"]]).rows.map(&:lexeme)
  end

  it "cannot serve Textbook audio at all, whatever the user's access" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))

    audible = create(:lexeme, kind: :word, text: "學校", audio_url: "/textbook/audio/x.mp3")

    [create(:user), create(:user, restricted_content: true)].each do |user|
      Current.set(user:) { expect(helper_audio(audible)).to(be_nil) }
    end
  end

  it "refuses the textbook keyword outright" do
    audible = create(:lexeme, kind: :word, text: "學校", audio_url: "/textbook/audio/x.mp3")

    expect { helper_audio(audible, textbook: true) }.to(raise_error(ArgumentError))
  end

  it "plays the MOE recording of the whole word and never the textbook file" do
    clip = Huayu::MoeAudio::Clip.new(scope: "words", id: "0004", head_ms: 800, zhuyin: "ㄅㄚ", pinyin: "bā")
    allow(Huayu::MoeAudio).to(receive(:for).and_return(clip))

    audible = create(:lexeme, kind: :word, text: "學校", audio_url: "/textbook/audio/x.mp3")

    Current.set(user: create(:user, restricted_content: true)) do
      expect(helper_audio(audible)).to(include("/audio/moe/"))
    end
  end

  it "stays silent when only the single characters are voiced" do
    allow(Huayu::MoeAudio).to(receive(:for).and_return(nil))

    audible = create(:lexeme, kind: :word, text: "學校", audio_url: "/textbook/audio/x.mp3")

    Current.set(user: create(:user, restricted_content: true)) do
      expect(helper_audio(audible)).to(be_nil)
    end
  end

  def helper_audio(lexeme, **options)
    tester = Object.new
    tester.extend(AudioHelper)
    tester.extend(Rails.application.routes.url_helpers)
    tester.define_singleton_method(:current_user) { Current.user }
    tester.define_singleton_method(:url_options) { {} }
    tester.audio_url_for(lexeme, **options)
  end
end
