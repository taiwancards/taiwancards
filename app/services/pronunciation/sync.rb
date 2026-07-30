# frozen_string_literal: true

require "digest"
require "open3"
require "shellwords"
require "tmpdir"

module Pronunciation
  class Sync
    REMOTE_ROOT = "/var/data/pronunciation"
    DEFAULT_REGION = "singapore"
    PAYLOAD = %w[templates thresholds.json inventory.json drills.json axis_norms.json].freeze

    STAGING = %r{(\A|/)[^/]+\.(old|prev|staging)(/|\z)}

    Result = Struct.new(:added, :changed, :removed, :unchanged, :bytes, keyword_init: true)

    def initialize(server:, region: DEFAULT_REGION, source: nil, remote_root: REMOTE_ROOT, io: $stdout)
      @server = normalize_server(server)
      @host = "#{@server}@ssh.#{region}.render.com"
      @source = source || Rails.root.join("data/pronunciation").to_s
      @remote_root = remote_root
      @io = io
      @control_path = control_socket_path
    end

    attr_reader :host, :source, :remote_root

    def call(dry_run: false)
      say("server      #{@host}")
      say("source      #{@source}")
      say("destination #{@remote_root}")
      say("")

      local = step("Computing local checksums") { local_manifest }
      abort_with("#{@source} contains none of: #{PAYLOAD.join(", ")}") if local.empty?

      check_ssh!
      remote = step("Reading the remote manifest") { remote_manifest }

      plan = diff(local, remote)
      report(plan, local)
      return plan if plan.added.empty? && plan.changed.empty?

      if dry_run
        say("\nDry run: nothing was uploaded.")
        return plan
      end

      upload(local, plan)
      verify!(local)
      plan
    ensure
      close_connection
    end

    private

    def control_socket_path
      digest = Digest::SHA256.hexdigest(@server)[0, 10]
      "/tmp/.ps-#{digest}"
    end

    def normalize_server(server)
      raise ArgumentError, "server is not specified" if server.blank?

      s = server.to_s.strip
      s.start_with?("srv-") ? s : "srv-#{s}"
    end

    def files_in_payload
      PAYLOAD.flat_map do |entry|
        path = File.join(@source, entry)
        if File.directory?(path)
          Dir.glob(File.join(path, "**", "*")).select { |f| File.file?(f) }
        elsif File.file?(path)
          [path]
        else
          []
        end
      end
    end

    def local_manifest
      files_in_payload.to_h do |abs|
        rel = abs.delete_prefix("#{@source}/")
        [rel, {"sha" => Digest::SHA256.file(abs).hexdigest, "size" => File.size(abs)}]
      end
    end

    def remote_manifest
      script = <<~SH
        set -e
        if [ ! -d #{@remote_root.shellescape} ]; then echo "__MISSING__"; exit 0; fi
        cd #{@remote_root.shellescape}
        find . -type f -print0 | xargs -0 sha256sum 2>/dev/null | sed 's|\\./||'
      SH
      out, status = ssh(script)
      return {} unless status.success?
      return {} if out.include?("__MISSING__")

      out
        .each_line
        .filter_map do |line|
          sha, path = line.strip.split(/\s+/, 2)
          next if sha.nil? || path.nil?

          [path, {"sha" => sha}]
        end
        .to_h
    end

    def diff(local, remote)
      added = local.keys - remote.keys
      removed = remote.keys - local.keys
      common = local.keys & remote.keys
      changed = common.select { |k| local[k]["sha"] != remote[k]["sha"] }
      Result.new(
        added: added.sort,
        changed: changed.sort,
        removed: removed.sort,
        unchanged: common.length - changed.length,
        bytes: (added + changed).sum { |k| local[k]["size"].to_i }
      )
    end

    def report(plan, local)
      say("")
      say("  unchanged  #{plan.unchanged}")
      say("  added      #{plan.added.length}")
      say("  changed    #{plan.changed.length}")
      if plan.removed.any?
        leftovers, strangers = plan.removed.partition { |path| STAGING.match?(path) }
        say("  extra on the server #{plan.removed.length}")

        strangers.first(5).each { |path| say("      #{path}") }
        say("      … and #{strangers.length - 5} more") if strangers.length > 5
        say(
          "  Extra files are NOT deleted: unrelated data in #{@remote_root} must not be touched."
        )

        if leftovers.any?
          say("")
          say(
            "  Of these, #{leftovers.length} are leftovers from an interrupted upload"
          )
          say(
            "  (#{leftovers.first.split("/").first}). Remove with: rake pronunciation:cleanup[#{@server.delete_prefix("srv-")}]"
          )
        end
      end

      if plan.added.empty? && plan.changed.empty?
        say(
          "\nEverything already matches; nothing to upload. Files on the server: #{local.length}."
        )
      elsif plan.unchanged.zero? && plan.changed.empty?
        say(
          "\n  Server is empty: first upload, #{plan.added.length} files, #{human(plan.bytes)}"
        )
      else
        say("\n  to upload: #{plan.added.length + plan.changed.length} files, #{human(plan.bytes)}")
      end
    end

    def upload(local, plan)
      to_send = plan.added + plan.changed
      Dir.mktmpdir do |tmp|
        archive = File.join(tmp, "pronunciation.tar.gz")
        step("Packing #{to_send.length} files") do
          list = File.join(tmp, "files.txt")
          File.write(list, to_send.join("\n"))
          run!("tar", "-czf", archive, "-C", @source, "-T", list)
        end

        size = File.size(archive)
        ratio = plan.bytes.to_i.positive? ? " (compressed to #{(100.0 * size / plan.bytes).round}%)" : ""
        say("  archive #{human(size)}#{ratio}")

        stream_upload(archive, size)
        unpack!
      end
    end

    def unpack!
      step("Unpacking and swapping the directory") do
        out, status = ssh(unpack_script)
        unless status.success? && out.include?("__SWAPPED__")
          abort_with("unpacking failed: #{out}")
        end
      end
    end

    def unpack_script
      <<~SH
        set -e
        ROOT=#{@remote_root.shellescape}
        STAGE="$ROOT.staging"
        rm -rf "$STAGE"
        mkdir -p "$STAGE"
        if [ -d "$ROOT" ]; then cp -a "$ROOT/." "$STAGE/"; fi
        tar -xzf /tmp/pronunciation.tar.gz -C "$STAGE"
        rm -f /tmp/pronunciation.tar.gz
        if [ -d "$ROOT" ]; then rm -rf "$ROOT.prev"; mv "$ROOT" "$ROOT.prev"; fi
        mv "$STAGE" "$ROOT"
        echo "__SWAPPED__"
      SH
    end

    def verify!(local)
      remote = step("Verifying checksums after upload") { remote_manifest }
      bad = local.reject { |path, meta| remote[path] && remote[path]["sha"] == meta["sha"] }
      if bad.empty?
        say("\n  All #{local.length} files match.")
        rollback_cleanup
      else
        say("\n  MISMATCH in #{bad.length} files:")
        bad.keys.first(10).each { |f| say("      #{f}") }
        abort_with(
          "verification failed. The previous version is kept at #{@remote_root}.prev; restore with: mv #{@remote_root}.prev #{@remote_root}"
        )
      end
    end

    def mirror!(dest)
      FileUtils.mkdir_p(dest)
      step("Downloading the server mirror into #{dest}") do
        archive = File.join(dest, ".remote.tar.gz")
        cmd = "tar -czf - -C #{@remote_root.shellescape} ."
        File.open(archive, "wb") do |f|
          Open3.popen3(*ssh_command(@host, cmd)) do |stdin, out, err, wait|
            stdin.close
            out.binmode
            IO.copy_stream(out, f)
            unless wait.value.success?
              abort_with("mirror download failed: #{err.read.strip}")
            end
          end
        end

        run!("tar", "-xzf", archive, "-C", dest)
        File.delete(archive)
      end

      dest
    end

    def rollback_cleanup
      ssh("rm -rf #{@remote_root.shellescape}.prev")
      say("  Previous version removed; rollback is no longer available.")
    end

    def stream_upload(archive, size)
      say("Uploading #{human(size)}")
      sent = 0
      started = Time.now
      cmd = ssh_command(@host, "cat > /tmp/pronunciation.tar.gz")
      Open3.popen3(*cmd) do |stdin, _out, err, wait|
        stdin.binmode
        File.open(archive, "rb") do |f|
          while (chunk = f.read(256 * 1024))
            stdin.write(chunk)
            sent += chunk.bytesize
            draw_bar(sent, size, started)
          end
        end

        stdin.close
        status = wait.value
        unless status.success?
          abort_with("transfer failed: #{err.read.force_encoding(Encoding::UTF_8).scrub.strip}")
        end
      end

      @io.print("\n")
    end

    def draw_bar(done, total, started)
      width = 32
      frac = total.zero? ? 1.0 : done.to_f / total
      filled = (frac * width).round
      elapsed = Time.now - started
      rate = elapsed.positive? ? done / elapsed : 0
      eta = (rate.positive? && done < total) ? ((total - done) / rate).round : 0
      @io.print(
        format(
          "\r  [%s%s] %3d%%  %s / %s  %s/s  eta %s   ",
          "█" * filled,
          "·" * (width - filled),
          (frac * 100).round,
          human(done),
          human(total),
          human(rate.round),
          eta.zero? ? "—" : "#{eta}s"
        )
      )
      @io.flush
    end

    def check_ssh!
      step(
        "Opening the connection (the first Render connection takes about 40s)"
      ) do
        _, status = ssh("echo ok")
        unless status.success?
          abort_with(
            "cannot connect to #{@host}. Check that the SSH key is registered in Render and the service is running."
          )
        end
      end
    end

    SSH_OPTIONS = [
      "-o",
      "BatchMode=yes",
      "-o",
      "ConnectTimeout=30",
      "-o",
      "UpdateHostKeys=no",
      "-o",
      "ServerAliveInterval=15"
    ].freeze

    def ssh_command(*args)
      ["ssh", *SSH_OPTIONS, *multiplex_options, *args]
    end

    def multiplex_options
      return [] if @multiplex == false

      ["-o", "ControlMaster=auto", "-o", "ControlPath=#{@control_path}", "-o", "ControlPersist=120"]
    end

    def ssh(script)
      Open3.capture2e(*ssh_command(@host, script))
    end

    public

    def cleanup(dry_run: false)
      check_ssh!
      found = ssh(
        "ls -d #{@remote_root.shellescape}*.old #{@remote_root.shellescape}*.prev " \
          "#{@remote_root.shellescape}*.staging #{@remote_root.shellescape}/*.old " \
          "#{@remote_root.shellescape}/*.prev 2>/dev/null"
      )
        .first
        .lines
        .map(&:strip)
        .compact_blank

      return say("No leftovers from previous uploads.") if found.empty?

      say("Leftovers from previous uploads:")
      found.each { |path| say("  #{path}") }
      return say("\nDry run: nothing was removed.") if dry_run

      out, status = ssh("rm -rf #{found.map(&:shellescape).join(" ")} && echo __DONE__")
      abort_with("cleanup failed: #{out}") unless status.success? && out.include?("__DONE__")
      say("\nDirectories removed: #{found.length}.")
      found
    ensure
      close_connection
    end

    private

    def close_connection
      Open3.capture2e(*ssh_command("-O", "exit", @host))
    rescue StandardError
      nil
    end

    def run!(*cmd)
      out, status = Open3.capture2e(*cmd)
      abort_with("#{cmd.first} failed: #{out}") unless status.success?
    end

    def step(label)
      @io.print("  #{label}… ")
      @io.flush
      started = Time.now
      result = yield
      @io.print("done in #{(Time.now - started).round(1)}s\n")
      result
    end

    def say(text) = @io.puts(text)

    def abort_with(message)
      raise message
    end

    def human(bytes)
      units = %w[B KB MB GB]
      value = bytes.to_f
      unit = 0
      while value >= 1024 && unit < units.length - 1
        value /= 1024
        unit += 1
      end

      format("%.1f %s", value, units[unit])
    end
  end
end
