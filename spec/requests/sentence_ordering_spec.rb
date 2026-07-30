# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sentence browsing" do
  let!(:colloquial) do
    ContentSource.create!(
      slug: "spoken",
      license_commercial: true,
      name: "Spoken",
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  let!(:publicistic) do
    ContentSource.create!(
      slug: "press",
      license_commercial: true,
      name: "Press",
      register: :publicistic,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Press."
    )
  end

  def sentence(text, source:, difficulty:, tocfl: nil, freq: nil)
    lexeme = Lexeme.new(kind: :sentence, text:, data: {"difficulty" => difficulty})
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!

    SentenceProfile.create!(
      lexeme:,
      difficulty:,
      han_length: text.scan(/\p{Han}/).length,
      tocfl_index: tocfl,
      tocfl_exact: tocfl.present?,
      freq_index: freq,
      freq_exact: freq.present?,
      registers: [ContentSource.registers[source.register]],
      source_ids: [source.id]
    )
    lexeme
  end

  let!(:easy_spoken) { sentence("我很好", source: colloquial, difficulty: 100, tocfl: 3, freq: 2) }
  let!(:mid_press) { sentence("今天天氣很好嗎", source: publicistic, difficulty: 400, tocfl: 4, freq: 4) }
  let!(:hard_press) do
    sentence(
      "這個週末我打算去臺北車站附近逛逛",
      source: publicistic,
      difficulty: 900,
      tocfl: 7,
      freq: 8
    )
  end

  def shown
    [easy_spoken, mid_press, hard_press].select { |item| response.body.include?(item.text) }
  end

  it "leads with the simplest sentence" do
    get(sentences_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body.index(easy_spoken.text)).to(be < response.body.index(hard_press.text))
  end

  it "treats a level as an upper bound, not an exact match" do
    get(sentences_path, params: {levels: {tocfl: "A2"}})

    expect(shown).to(contain_exactly(easy_spoken, mid_press))
  end

  it "widens the result when several registers are picked" do
    get(sentences_path, params: {registers: %w[colloquial publicistic]})
    expect(shown.length).to(eq(3))

    get(sentences_path, params: {registers: %w[colloquial]})
    expect(shown).to(contain_exactly(easy_spoken))
  end

  it "stacks level and frequency limits while widening registers" do
    get(
      sentences_path,
      params: {registers: %w[colloquial publicistic], levels: {tocfl: "A1", freq: "1000"}}
    )

    expect(shown).to(contain_exactly(easy_spoken))
  end

  it "hides sentences whose only source has been switched off" do
    publicistic.update!(enabled: false, enabled_for_admins: false)
    get(sentences_path)

    expect(shown).to(contain_exactly(easy_spoken))
  end

  it "opens a single sentence with its breakdown" do
    get(sentence_path(easy_spoken))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(easy_spoken.text))
  end
end
