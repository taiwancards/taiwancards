# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "the pruned_rejected_sentences sync step" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("huayu:prune_rejected_sentences") }

  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:step) { Deploy::SyncSteps::STEPS.find { |candidate| candidate.name == "pruned_rejected_sentences" } }
  let(:store) { Huayu::SentenceRejectStore }
  let(:word) { Lexeme.create!(kind: :word, text: "心") }
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
    file = scratch.join(store.path.basename)
    allow(store).to(receive(:path).and_return(file))
    allow(AppData).to(receive(:path).with("huayu/#{file.basename}").and_return(file))
  end

  after { scratch.rmtree }

  def listed(text, reason) = store.append([store::Entry.new(text:, reason:)])

  def sentence(text)
    lexeme = Lexeme.new(kind: :sentence, text:)
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    SentenceWord.create!(sentence: lexeme, lexeme: word)
    lexeme
  end

  def sync
    Rake::Task["huayu:prune_rejected_sentences"].reenable
    Deploy::Sync.new(scope: "content", io: StringIO.new).call
  end

  it "removes a listed fragment whose word keeps another example" do
    keeper = sentence("我的心很安靜。")
    fragment = sentence("常常讓我的心")
    listed(fragment.text, "fragment")

    expect(sync.ran).to(include("pruned_rejected_sentences"))
    expect(Lexeme.exists?(fragment.id)).to(be(false))
    expect(Lexeme.exists?(keeper.id)).to(be(true))
  end

  it "keeps a listed fragment that is the last example of its word" do
    fragment = sentence("常常讓我的心")
    listed(fragment.text, "fragment")

    expect(sync.ran).to(include("pruned_rejected_sentences"))
    expect(Lexeme.exists?(fragment.id)).to(be(true))
  end
end
