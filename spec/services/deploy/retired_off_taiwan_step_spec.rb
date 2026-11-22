# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "the retired_off_taiwan sync step" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("huayu:retire_off_taiwan") }

  let(:scratch) { Pathname(Dir.mktmpdir) }
  let(:step) { Deploy::SyncSteps::STEPS.find { |candidate| candidate.name == "retired_off_taiwan" } }
  let(:stores) { [Huayu::SentenceRejectStore, Huayu::CollocationRejectStore] }
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
    Rake::Task["huayu:retire_off_taiwan"].reenable
    Deploy::Sync.new(scope: "content", io: StringIO.new).call
  end

  it "removes the sentences and collocations listed as off_taiwan" do
    slogan = sentence("中國一點都不能少")
    office = Lexeme.create!(kind: :collocation, text: "公安局")
    listed(Huayu::SentenceRejectStore, slogan.text, "off_taiwan")
    listed(Huayu::CollocationRejectStore, office.text, "off_taiwan")

    expect(sync.ran).to(include("retired_off_taiwan"))
    expect(Lexeme.exists?(slogan.id)).to(be(false))
    expect(Lexeme.exists?(office.id)).to(be(false))
  end

  it "leaves the entries listed for other reasons to the manual purge" do
    fragment = sentence("常常讓我的心")
    stray = Lexeme.create!(kind: :collocation, text: "服務員")
    listed(Huayu::SentenceRejectStore, fragment.text, "fragment")
    listed(Huayu::CollocationRejectStore, stray.text, "off_corpus")

    expect(sync.ran).to(include("retired_off_taiwan"))
    expect(Lexeme.exists?(fragment.id)).to(be(true))
    expect(Lexeme.exists?(stray.id)).to(be(true))
  end
end
