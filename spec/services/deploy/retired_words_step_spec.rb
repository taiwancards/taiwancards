# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "the retired_words sync step" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("huayu:retire_words") }

  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:step) { Deploy::SyncSteps::STEPS.find { |candidate| candidate.name == "retired_words" } }
  let(:stores) { [Huayu::SentenceRejectStore, Huayu::CollocationRejectStore, Huayu::WordRejectStore] }
  let(:source) do
    ContentSource.create!(
      slug: "spoken",
      name: "Spoken",
      license_commercial: true,
      register: :colloquial,
      enabled: true,
      attribution: "Spoken."
    )
  end

  around do |example|
    original = $stdout
    $stdout = StringIO.new
    example.run
  ensure
    $stdout = original
  end

  before do
    allow(MaintenanceWindow).to(receive(:open!))
    allow(Deploy::DerivedCaches).to(receive_messages(refresh: nil, edge_configured?: false, purge_edge: nil))
    stub_const("Deploy::SyncSteps::STEPS", [step])
    stub_const("Deploy::SyncSteps::ALWAYS", {})
    allow(AppData).to(receive(:path).and_call_original)
    stores.each do |store|
      file = scratch.join(store.path.basename)
      allow(store).to(receive(:path).and_return(file))
      allow(AppData).to(receive(:path).with("huayu/#{file.basename}").and_return(file))
    end
  end

  after { scratch.rmtree }

  def listed(store, text, reason) = store.append([store::Entry.new(text:, reason:)])

  def sentence(text)
    lexeme = Lexeme.new(kind: :sentence, text:)
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  def sync
    Rake::Task["huayu:retire_words"].reenable
    Deploy::Sync.new(scope: "content", io: StringIO.new).call
  end

  it "depends on the word reject file alone" do
    expect(step.paths).to(eq(%w[huayu/word_rejects.jsonl]))
  end

  it "removes a listed word when the word reject file changes, under the content scope" do
    doomed = Lexeme.create!(kind: :word, text: "打吃")
    listed(Huayu::WordRejectStore, doomed.text, "renamed")

    expect(sync.ran).to(include("retired_words"))
    expect(Lexeme.exists?(doomed.id)).to(be(false))
  end

  it "leaves listed sentences and collocations to the manual purge" do
    kept_sentence = sentence("常常讓我的心")
    kept_collocation = Lexeme.create!(kind: :collocation, text: "服務員")
    listed(Huayu::SentenceRejectStore, kept_sentence.text, "fragment")
    listed(Huayu::CollocationRejectStore, kept_collocation.text, "off_corpus")
    listed(Huayu::WordRejectStore, "打吃", "renamed")

    expect(sync.ran).to(include("retired_words"))
    expect(Lexeme.exists?(kept_sentence.id)).to(be(true))
    expect(Lexeme.exists?(kept_collocation.id)).to(be(true))
  end

  it "does not wake up when only the sentence or collocation lists change" do
    listed(Huayu::WordRejectStore, "打吃", "renamed")
    sync
    listed(Huayu::SentenceRejectStore, "常常讓我的心", "fragment")
    listed(Huayu::CollocationRejectStore, "服務員", "off_corpus")

    expect(sync.skipped).to(include("retired_words"))
  end

  it "is skipped while the word reject file is unchanged" do
    listed(Huayu::WordRejectStore, "打吃", "renamed")
    sync
    Lexeme.create!(kind: :word, text: "打吃")

    expect(sync.skipped).to(include("retired_words"))
    expect(Lexeme.exists?(kind: :word, text: "打吃")).to(be(true))
  end

  it "runs again once a new word is listed" do
    listed(Huayu::WordRejectStore, "打吃", "renamed")
    sync
    doomed = Lexeme.create!(kind: :word, text: "定式")
    listed(Huayu::WordRejectStore, doomed.text, "renamed")

    expect(sync.ran).to(include("retired_words"))
    expect(Lexeme.exists?(doomed.id)).to(be(false))
  end

  it "leaves the manual purge in charge of all three lists" do
    doomed_sentence = sentence("常常讓我的心")
    doomed_collocation = Lexeme.create!(kind: :collocation, text: "服務員")
    doomed_word = Lexeme.create!(kind: :word, text: "打吃")
    listed(Huayu::SentenceRejectStore, doomed_sentence.text, "fragment")
    listed(Huayu::CollocationRejectStore, doomed_collocation.text, "off_corpus")
    listed(Huayu::WordRejectStore, doomed_word.text, "renamed")

    Rake::Task["huayu:purge_rejects"].reenable
    Rake::Task["huayu:purge_rejects"].invoke

    expect(Lexeme.where(id: [doomed_sentence.id, doomed_collocation.id, doomed_word.id])).to(be_empty)
  end
end
