# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "rake deploy:sync" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("deploy:sync") }

  let(:task) { Rake::Task["deploy:sync"] }

  def run_with(failed:)
    report = Deploy::Sync::Report.new(ran: ["probe"], skipped: [], failed:, elapsed: 0.1)
    allow(Deploy::Sync).to(receive(:new).and_return(instance_double(Deploy::Sync, call: report)))
    task.reenable
    task.invoke
  end

  it "passes when every step ran" do
    expect { run_with(failed: []) }.to(output(/deploy:sync ran \[probe\]/).to_stdout)
  end

  it "stops the release when a step failed, so the web never starts on a half-synced database" do
    expect {
      expect { run_with(failed: ["lexemes (ArgumentError)"]) }.to(output.to_stdout)
    }
      .to(
        raise_error(SystemExit) { |exit| expect(exit.status).not_to(eq(0)) }
          .and(output(/deploy:sync FAILED \[lexemes \(ArgumentError\)\]/).to_stderr)
      )
  end
end
