# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Regional notes" do
  before { Huayu::RegionalNotes.reset! }

  after { Huayu::RegionalNotes.reset! }

  def note(section, key) = CGI.escapeHTML(Huayu::RegionalNotes.for(section, key, "vi"))

  it "adds the Southern reading under a sound a Hanoi speaker lacks" do
    read_in("vi")
    get("/vi/practice/zhuyin", params: {part: "initials"})

    expect(response.body).to(include(note("initials", "sh")))
    expect(response.body).to(include(note("blocks", "retroflex")))
  end

  it "adds it under the finals and the rimes too" do
    read_in("vi")

    get("/vi/practice/zhuyin", params: {part: "finals"})
    expect(response.body).to(include(note("finals", "an")))

    get("/vi/practice/zhuyin", params: {part: "tricky"})
    expect(response.body).to(include(note("rimes", "-n vs -ng")))
  end

  it "sets the note in smaller type than the explanation it follows" do
    read_in("vi")
    get("/vi/practice/zhuyin", params: {part: "initials"})

    expect(response.body).to(
      match(/<p[^>]+data-regional-note[^>]+text-\[11px\]|<p[^>]+text-\[11px\][^>]+data-regional-note/)
    )
  end

  it "compares the tones of the South and of Huế on the tones page" do
    read_in("vi")
    get("/vi/tones")

    Huayu::RegionalNotes.notes("vi").fetch("tones").each_value do |text|
      expect(response.body).to(include(CGI.escapeHTML(text)))
    end
  end

  it "adds the Southern particles to a grammar lesson built on Northern ones" do
    read_in("vi")
    get("/vi/grammar/ba-particle")

    expect(response.body).to(include(note("grammar", "ba-particle")))
  end

  it "adds them to the page of a sentence-final particle" do
    create(
      :lexeme,
      kind: :particle,
      text: "吧",
      readings: {"pinyin" => "ba", "zhuyin" => "˙ㄅㄚ"},
      meanings: {"en" => "softens a suggestion", "vi" => "làm mềm lời đề nghị"},
      data: {"rank" => 1, "family" => "core", "corpus" => 100}
    )
    read_in("vi")
    get("/vi/zhuci/#{CGI.escape("吧")}")

    expect(response.body).to(include(note("particles", "吧")))
  end

  it "shows nothing of the kind to a reader of another language" do
    get("/en/practice/zhuyin", params: {part: "initials"})
    expect(response.body).not_to(include("data-regional-note"))

    get("/en/tones")
    expect(response.body).not_to(include("data-regional-note"))

    get("/en/grammar/ba-particle")
    expect(response.body).not_to(include("data-regional-note"))
  end
end
