# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deploy::Rollout do
  let(:io) { StringIO.new }
  let(:shipper) { instance_double(Content::Shipper, host: "srv-x@ssh.singapore.render.com") }

  def rollout(**options)
    described_class.new(server: "srv-x", io:, **options).tap do |instance|
      allow(instance).to(receive(:shipper).and_return(shipper))
    end
  end

  describe "#plan" do
    it "says what will travel and how much of it" do
      lines = rollout.plan.join("\n")

      expect(lines).to(include("pronunciation"))
      expect(lines).to(include("total to transfer"))
    end

    it "warns that the dictionary is skipped without a production database" do
      expect(rollout.plan.join("\n")).to(include("SKIPPED"))
    end
  end

  describe "#call" do
    before do
      allow(shipper).to(receive(:sync_paths))
      allow(shipper).to(receive(:ensure_dirs))
      allow(shipper).to(receive(:run_remote))
    end

    it "refuses to run when a required section is absent locally" do
      section = Deploy::Catalog.find("huayu")
      allow(section).to(receive(:exist?).and_return(false))
      allow(Deploy::Catalog).to(receive(:select).and_return([section]))

      expect { rollout.call }.to(raise_error(/required sections are missing/))
    end

    it "checksums pronunciation and rsyncs the rest" do
      sync = instance_double(Pronunciation::Sync)
      result = Pronunciation::Sync::Result.new(added: [], changed: %w[a], removed: [], unchanged: 2, bytes: 10)
      allow(Pronunciation::Sync).to(receive(:new).and_return(sync))
      allow(sync).to(receive(:call).with(dry_run: false).and_return(result))

      rollout(only: "huayu,pronunciation").call

      expect(shipper).to(have_received(:sync_paths).once)
      expect(sync).to(have_received(:call).once)
    end

    it "runs migrations before anything that writes to the database" do
      rollout(only: "huayu").call

      script = nil
      expect(shipper).to(have_received(:run_remote) { |command| script = command })
      expect(script.index("db:prepare")).to(be < script.index("deploy:sync"))
      expect(script).to(include("textbook:load"))
    end

    it "lets each server task fail on its own" do
      rollout(only: "huayu").call

      expect(shipper).to(have_received(:run_remote).with(/fail=1/))
    end

    it "survives a broken ssh session and says so" do
      allow(shipper).to(receive(:run_remote).and_raise("connection reset"))

      steps = rollout(only: "huayu").call

      expect(steps.find { |step| step.name == "server" }.status).to(eq(:failed))
      expect(io.string).to(include("updated on the next Render restart"))
    end

    it "leaves a section alone when it is absent locally" do
      audio = Deploy::Catalog.find("textbook_audio")
      huayu = Deploy::Catalog.find("huayu")
      allow(audio).to(receive(:exist?).and_return(false))
      allow(Deploy::Catalog).to(receive(:select).and_return([huayu, audio]))

      step = rollout.call.find { |entry| entry.name == "textbook_audio" }

      expect(step.status).to(eq(:skipped))
      expect(step.note).to(include("server not modified"))
      expect(shipper).to(have_received(:sync_paths).once)
    end

    describe "a dry run" do
      it "asks rsync to show without sending, and writes nothing else" do
        steps = rollout(only: "huayu", dry_run: true).call

        expect(shipper).to(have_received(:sync_paths).with(anything, "huayu", dry_run: true, checksum: false))
        expect(shipper).not_to(have_received(:ensure_dirs))
        expect(shipper).not_to(have_received(:run_remote))
        expect(steps.map(&:status)).to(include(:dry))
      end
    end

    it "can compare contents instead of dates" do
      rollout(only: "huayu", checksum: true).call

      expect(shipper).to(have_received(:sync_paths).with(anything, "huayu", dry_run: false, checksum: true))
    end

    it "reports every step at the end" do
      steps = rollout(only: "huayu").call

      expect(steps.map(&:name)).to(include("huayu", "dictionary", "server", "verification"))
      expect(io.string).to(include("✓"))
    end
  end
end
