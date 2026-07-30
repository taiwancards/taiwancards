# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Sync do
  let(:source) { Dir.mktmpdir }
  let(:io) { StringIO.new }

  before do
    FileUtils.mkdir_p(File.join(source, "templates", "taiwan"))
    File.write(File.join(source, "templates", "taiwan", "gao1.json"), "{\"key\":\"gao1\"}")
    File.write(File.join(source, "templates", "taiwan", "kao1.json"), "{\"key\":\"kao1\"}")
    File.write(File.join(source, "thresholds.json"), "{\"overall\":{\"red\":62}}")
    File.write(File.join(source, "inventory.json"), "{\"keys\":{}}")
    File.write(File.join(source, "drills.json"), "{\"sections\":[]}")
  end

  after { FileUtils.remove_entry(source) }

  subject(:sync) { described_class.new(server: "abc123", source:, io:) }

  describe "server naming" do
    it "accepts the bare id from the Render ssh string" do
      expect(described_class.new(server: "abc123", source:, io:).host).to(eq("srv-abc123@ssh.singapore.render.com"))
    end

    it "accepts the full srv- form unchanged" do
      expect(described_class.new(server: "srv-abc123", source:, io:).host).to(eq("srv-abc123@ssh.singapore.render.com"))
    end

    it "honors a different region" do
      instance = described_class.new(server: "abc123", region: "frankfurt", source:, io:)
      expect(instance.host).to(eq("srv-abc123@ssh.frankfurt.render.com"))
    end

    it "refuses to run without a server" do
      expect { described_class.new(server: "", source:, io:) }.to(raise_error(ArgumentError))
    end
  end

  describe "planning" do
    def plan_against(remote)
      local = sync.send(:local_manifest)
      sync.send(:diff, local, remote)
    end

    it "treats an empty server as a full upload" do
      plan = plan_against({})
      expect(plan.added.length).to(eq(5))
      expect(plan.changed).to(be_empty)
      expect(plan.unchanged).to(eq(0))
    end

    it "sends nothing when every checksum already matches" do
      local = sync.send(:local_manifest)
      plan = sync.send(:diff, local, local)
      expect(plan.added).to(be_empty)
      expect(plan.changed).to(be_empty)
      expect(plan.unchanged).to(eq(5))
    end

    it "sends only the files whose contents differ" do
      local = sync.send(:local_manifest)
      remote = local.transform_values(&:dup)
      remote["thresholds.json"]["sha"] = "0" * 64
      plan = sync.send(:diff, local, remote)
      expect(plan.changed).to(eq(["thresholds.json"]))
      expect(plan.added).to(be_empty)
    end

    it "prints a report for every branch it can reach" do
      local = sync.send(:local_manifest)

      expect { sync.send(:report, sync.send(:diff, local, {}), local) }.not_to(raise_error)
      expect(io.string).to(include("Server is empty"))

      io.truncate(0)
      expect { sync.send(:report, sync.send(:diff, local, local), local) }.not_to(raise_error)
      expect(io.string).to(include("Everything already matches"))

      io.truncate(0)
      partial = local.transform_values(&:dup)
      partial["thresholds.json"]["sha"] = "0" * 64
      expect { sync.send(:report, sync.send(:diff, local, partial), local) }.not_to(raise_error)
      expect(io.string).to(include("to upload"))
    end

    it "reports extra remote files but never plans to delete them" do
      local = sync.send(:local_manifest)
      remote = local.merge("someone_elses_backup.sql" => {"sha" => "1" * 64})
      plan = sync.send(:diff, local, remote)
      expect(plan.removed).to(eq(["someone_elses_backup.sql"]))

      sync.send(:report, plan, local)
      expect(io.string).to(include("NOT deleted"))
    end

    it "tells our own interrupted-run leftovers apart from a stranger's data" do
      local = sync.send(:local_manifest)
      remote = local.merge(
        "templates.old/taiwan/a1.json" => {"sha" => "1" * 64},
        "someone_elses_backup.sql" => {"sha" => "2" * 64}
      )

      sync.send(:report, sync.send(:diff, local, remote), local)

      expect(io.string).to(include("leftovers from an interrupted upload"))
      expect(io.string).to(include("pronunciation:cleanup"))
      expect(io.string).to(include("someone_elses_backup.sql"))
    end

    it "stops when nothing has to travel, however much junk sits on the server" do
      local = sync.send(:local_manifest)
      remote = local.merge("templates.old/taiwan/a1.json" => {"sha" => "1" * 64})
      allow(sync).to(receive(:local_manifest).and_return(local))
      allow(sync).to(receive(:remote_manifest).and_return(remote))
      allow(sync).to(receive(:check_ssh!))
      allow(sync).to(receive(:close_connection))
      expect(sync).not_to(receive(:upload))

      plan = sync.call

      expect(plan.removed).to(eq(["templates.old/taiwan/a1.json"]))
      expect(io.string).to(include("Everything already matches"))
    end
  end

  describe "ssh invocation" do
    it "declines the host-key update that Render's proxy breaks" do
      expect(sync.send(:ssh_command, "host", "true")).to(include("UpdateHostKeys=no"))
    end

    it "drops the speculative host-key policy that was never needed" do
      expect(sync.send(:ssh_command, "host", "true").join(" ")).not_to(include("StrictHostKeyChecking"))
    end

    it "can fall back to plain connections when the control socket misbehaves" do
      sync.instance_variable_set(:@multiplex, false)
      expect(sync.send(:ssh_command, "host", "true").join(" ")).not_to(include("ControlMaster"))
    end

    it "keeps the control socket short enough for a real Render id" do
      long_id = "d9divrrtqb8s738qdpmg"
      instance = described_class.new(server: long_id, source:, io:)
      path = instance.send(:control_socket_path)
      expect(path.length + 17).to(be < 104)
    end

    it "gives different servers different sockets" do
      a = described_class.new(server: "aaa", source:, io:).send(:control_socket_path)
      b = described_class.new(server: "bbb", source:, io:).send(:control_socket_path)
      expect(a).not_to(eq(b))
    end

    it "reuses one connection across the whole run" do
      cmd = sync.send(:ssh_command, "host", "true")
      expect(cmd).to(include("ControlMaster=auto"))
      expect(cmd.join(" ")).to(include("ControlPath="))
    end
  end

  describe "binary transfer" do
    it "streams the archive through a pipe without corrupting it" do
      Dir.mktmpdir do |tmp|
        src = File.join(tmp, "a.gz")
        dst = File.join(tmp, "b.gz")
        File.binwrite(src, "\x1f\x8b\x08\x00".b + Random.bytes(4096))

        Open3.popen3("cat") do |stdin, out, _err, wait|
          stdin.binmode
          out.binmode
          reader = Thread.new { File.binwrite(dst, out.read) }
          File.open(src, "rb") do |f|
            while (chunk = f.read(1024))
              stdin.write(chunk)
            end
          end

          stdin.close
          reader.join
          wait.value
        end

        expect(File.binread(dst)).to(eq(File.binread(src)))
      end
    end
  end

  describe "the remote script" do
    it "keeps the previous version until the new one is in place" do
      script = sync.send(:unpack_script)
      expect(script).to(include(".staging"))
      expect(script).to(include(".prev"))
      expect(script.index("mv \"$ROOT\" \"$ROOT.prev\"")).to(be < script.index("mv \"$STAGE\" \"$ROOT\""))
    end

    it "builds the staging tree from the live one so untouched files survive" do
      expect(sync.send(:unpack_script)).to(include("cp -a \"$ROOT/.\" \"$STAGE/\""))
    end
  end
end
