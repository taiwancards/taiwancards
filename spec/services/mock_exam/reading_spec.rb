# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockExam::Reading do
  let!(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      enabled_for_admins: true,
      attribution: "Spoken."
    )
  end

  def word(text)
    create(:lexeme, kind: :word, text:, data: {"tocfl_level" => "Novice1"}, meanings: {"en" => text})
  end

  def sentence_with(word_lexeme, text)
    sentence = Lexeme.new(kind: :sentence, text:, meanings: {"en" => "example"}, data: {"tocfl_level" => "Novice1"})
    sentence.lexeme_content_sources.build(content_source: source)
    sentence.save!
    sentence.update_columns(tocfl_half: 1)
    SentenceProfile.create!(
      lexeme: sentence,
      difficulty: 100,
      han_length: text.scan(/\p{Han}/).length,
      registers: [ContentSource.registers[source.register]],
      source_ids: [source.id]
    )
    SentenceWord.create!(sentence:, lexeme: word_lexeme, gdex: 500)
    sentence
  end

  before do
    %w[學校 朋友 老師 醫生].each { |text| word(text) }
    sentence_with(Lexeme.find_by(text: "學校"), "我每天去學校上課。")
    sentence_with(Lexeme.find_by(text: "朋友"), "他是我最好的朋友之一。")
  end

  it "builds a deterministic cloze paper for a band" do
    first = described_class.build(band: "novice", seed: 42)
    second = described_class.build(band: "novice", seed: 42)

    expect(first.questions).not_to(be_empty)
    expect(first.questions.map(&:text)).to(eq(second.questions.map(&:text)))
    expect(first.questions.map(&:options)).to(eq(second.questions.map(&:options)))
  end

  it "blanks the target word and keys the answer to it" do
    paper = described_class.build(band: "novice", seed: 7)
    question = paper.questions.first

    expect(question.cloze).to(include(MockExam::Reading::BLANK))
    expect(question.options.size).to(eq(3))
    expect(question.text).to(include(question.options[question.answer]))
    expect(question.cloze).not_to(include(question.options[question.answer]))
  end
end
