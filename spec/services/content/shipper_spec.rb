# frozen_string_literal: true

require "rails_helper"

RSpec.describe Content::Shipper do
  let(:io) { StringIO.new }

  subject(:shipper) { described_class.new(server: "abc123", io:) }

  describe "addressing" do
    it "accepts the bare id from the Render ssh string" do
      expect(shipper.host).to(eq("srv-abc123@ssh.singapore.render.com"))
    end

    it "accepts the full srv- form unchanged" do
      expect(described_class.new(server: "srv-abc123", io:).host).to(eq("srv-abc123@ssh.singapore.render.com"))
    end

    it "refuses to run without a server" do
      expect { described_class.new(server: "", io:) }.to(raise_error(ArgumentError))
    end
  end

  describe "ssh options Render needs" do
    it "declines the host-key update that Render's proxy breaks" do
      expect(shipper.send(:ssh_command, "host", "true")).to(include("UpdateHostKeys=no"))
    end
  end

  describe "unpacking" do
    it "replaces the pronunciation templates instead of merging into them" do
      script = shipper.send(:ssh_command, "host", "x")
      expect(described_class::REPLACED_DIRS).to(include("pronunciation/templates"))
      expect(script).to(be_an(Array))
    end

    it "keeps the previous templates until the new ones are in place" do
      allow(shipper).to(receive(:system).and_return(true))
      allow(shipper).to(receive(:ssh_command)) { |_host, remote| ["true", remote] }

      shipper.unpack("/var/data/payload.tar.gz")

      expect(io.string).to(include("Unpacked"))
    end
  end

  describe "the rsync invocation" do
    def command(**options)
      shipper.send(:rsync_command, ["/local/audio/textbook"], "/var/data/audio/textbook/", **options)
    end

    it "never deletes anything on the server" do
      expect(command).not_to(include("--delete"))
      expect(command).not_to(include(a_string_matching(/--delete/)))
    end

    it "keeps timestamps so the next run can skip what matches" do
      expect(command.first(2)).to(eq(["rsync", "-rltvz"]))
    end

    it "can compare contents instead of dates" do
      expect(command(checksum: true)).to(include("--checksum"))
      expect(command).not_to(include("--checksum"))
    end

    it "can show what would travel without sending it" do
      expect(command(dry_run: true)).to(include("--dry-run"))
      expect(command).not_to(include("--dry-run"))
    end
  end

  describe "#ensure_dirs" do
    it "creates the nested targets in one call" do
      allow(shipper).to(receive(:run_remote))

      shipper.ensure_dirs(%w[huayu audio/textbook])

      expect(shipper).to(have_received(:run_remote).with("mkdir -p /var/data/audio/textbook"))
    end

    it "says nothing when every target is a single level" do
      allow(shipper).to(receive(:run_remote))

      shipper.ensure_dirs(%w[huayu moe_audio])

      expect(shipper).not_to(have_received(:run_remote))
    end
  end
end
