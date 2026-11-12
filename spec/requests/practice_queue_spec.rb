# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Practice queues kept in the session cookie" do
  let(:session_key) { Rails.application.config.session_options[:key] }
  let(:legacy_key) { /\A(pron|writing)_(queue|position)/ }

  before do
    allow(Huayu::StrokeData).to(receive(:has?).and_return(true))
  end

  def cookie_jar
    request = ActionDispatch::TestRequest.create(Rails.application.env_config)
    ActionDispatch::Cookies::CookieJar.build(request, session_key => cookies[session_key].to_s)
  end

  def stored_session = cookie_jar.encrypted[session_key].to_h

  def store_session(data)
    jar = cookie_jar
    jar.encrypted[session_key] = {value: data}
    cookies[session_key] = jar[session_key]
  end

  def cookie_bytes = session_key.bytesize + CGI.escape(cookies[session_key].to_s).bytesize

  def characters(count, from:)
    Array.new(count) do |index|
      create(
        :lexeme,
        id: from + index,
        kind: :character,
        text: (0x4E00 + (from % 10_000) + index).chr(Encoding::UTF_8),
        readings: {"pinyin" => "mā", "zhuyin" => "ㄇㄚ"},
        data: {"moe_index" => index + 1}
      )
    end
  end

  def deck(lexemes, name:)
    Collection.create!(user: current_user, name:, kind: :manual).tap { |collection|
      collection.add_lexemes(lexemes.map(&:id))
    }
  end

  def decks(count, lexemes)
    Array.new(count) { |index| deck(lexemes, name: "Deck #{index}") }
  end

  it "practises pronunciation across a dozen decks without outgrowing the cookie" do
    lexemes = characters(30, from: 330_000)

    decks(12, lexemes).each do |collection|
      get("/pronunciation", params: {collection_id: collection.id})

      expect(response).to(have_http_status(:ok))
    end

    expect(stored_session.keys.grep(/\Apron_/)).to(eq(["pron_practice"]))
  end

  it "practises writing across a dozen decks without outgrowing the cookie" do
    lexemes = characters(30, from: 331_000)

    decks(12, lexemes).each do |collection|
      get("/writing", params: {collection_id: collection.id})

      expect(response).to(have_http_status(:ok))
    end

    expect(stored_session.keys.grep(/\Awriting_/)).to(eq(["writing_practice"]))
  end

  it "drops the per-deck queues an older version left in the cookie" do
    lexemes = characters(3, from: 332_000)
    collection = deck(lexemes, name: "Old")
    get("/pronunciation")
    legacy = {
      "pron_queue" => [1, 2, 3],
      "pron_position" => 1,
      "pron_queue_#{collection.id}" => (1..30).to_a,
      "pron_position_#{collection.id}" => 4,
      "writing_queue" => [4, 5],
      "writing_position" => 0,
      "writing_queue_99" => (1..30).to_a,
      "writing_position_99" => 2,
      "pron_section_tones" => 3
    }
    store_session(stored_session.merge(legacy))

    get("/writing")

    expect(stored_session.keys.grep(legacy_key)).to(be_empty)
    expect(stored_session).to(include("pron_section_tones" => 3))
  end

  it "cleans the old queues when a study sitting starts too" do
    characters(3, from: 333_000)
    get("/pronunciation")
    store_session(stored_session.merge("pron_queue_5" => (1..30).to_a, "writing_position_5" => 1))

    get("/study", params: {mode: "cram", size: 3})

    expect(stored_session.keys.grep(legacy_key)).to(be_empty)
  end

  it "resumes the same deck where the learner left off" do
    lexemes = characters(5, from: 334_000)
    collection = deck(lexemes, name: "Resume")

    get("/pronunciation", params: {collection_id: collection.id})
    2.times { get("/pronunciation", params: {collection_id: collection.id, advance: 1}) }
    get("/pronunciation", params: {collection_id: collection.id})

    slot = stored_session["pron_practice"]
    expect(slot).to(include("deck" => collection.id, "pos" => 2))
    shown = Lexeme.find(Study::Run.unpack(slot["ids"])[2])
    expect(response.body).to(include("data-pronunciation-lexeme-id-value=\"#{shown.id}\""))
  end

  it "starts the queue over once the learner walks past its end" do
    lexemes = characters(3, from: 335_000)
    collection = deck(lexemes, name: "Wrap")

    get("/writing", params: {collection_id: collection.id})
    3.times { get("/writing", params: {collection_id: collection.id, advance: 1}) }

    expect(stored_session["writing_practice"]).to(include("deck" => collection.id, "pos" => 0))
  end

  it "replaces the slot when the learner moves to another deck" do
    first = deck(characters(3, from: 336_000), name: "First")
    second = deck(characters(3, from: 336_100), name: "Second")

    get("/writing", params: {collection_id: first.id})
    get("/writing", params: {collection_id: first.id, advance: 1})
    get("/writing", params: {collection_id: second.id})

    expect(stored_session["writing_practice"]).to(include("deck" => second.id, "pos" => 0))
  end

  it "stays under the browser cookie limit after a full sitting and both trainers" do
    lexemes = characters(Study::CardSet::SITTING_CAP, from: 337_000)
    sitting = deck(lexemes, name: "Sitting")
    practice = deck(lexemes.first(60), name: "Practice")

    get("/study", params: {mode: "cram", size: Study::CardSet::SITTING_CAP, collection_id: sitting.id})
    expect(response).to(have_http_status(:ok))
    get("/pronunciation", params: {collection_id: practice.id})
    expect(response).to(have_http_status(:ok))
    get("/writing", params: {collection_id: practice.id})
    expect(response).to(have_http_status(:ok))

    expect(Study::Run.unpack(stored_session.dig("study", "ids")).size).to(eq(Study::CardSet::SITTING_CAP))
    expect(cookie_bytes).to(be < 4096)
  end
end
