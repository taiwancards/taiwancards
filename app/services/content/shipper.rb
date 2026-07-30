# frozen_string_literal: true

module Content
  class Shipper
    DEFAULT_REGION = "singapore"
    REMOTE_DIR = "/var/data"

    SSH_OPTIONS = [
      "-o",
      "BatchMode=yes",
      "-o",
      "ConnectTimeout=30",
      "-o",
      "StrictHostKeyChecking=accept-new",
      "-o",
      "UpdateHostKeys=no",
      "-o",
      "ServerAliveInterval=15"
    ].freeze

    def initialize(server:, region: DEFAULT_REGION, io: $stdout)
      raise ArgumentError, "a Render service id is required" if server.blank?

      @server = server.to_s.sub(/\Asrv-/, "")
      @region = region.presence || DEFAULT_REGION
      @io = io
    end

    def host
      "srv-#{@server}@ssh.#{@region}.render.com"
    end

    def call(path, remote_name: nil)
      source = Pathname(path)
      raise ArgumentError, "no such file: #{source}" unless source.exist?

      name = remote_name.presence || source.basename.to_s
      target = File.join(REMOTE_DIR, name)
      size = source.size

      @io.puts("→ connecting to #{host} …")
      check!
      @io.puts("→ sending #{source.basename} (#{human(size)}) to #{target}")

      command = ssh_command(host, "cat > #{target.shellescape}")
      sent = 0
      Open3.popen3(*command) do |stdin, _out, err, wait|
        stdin.binmode
        source.open("rb") do |file|
          while (chunk = file.read(1 << 20))
            stdin.write(chunk)
            sent += chunk.bytesize
            progress(sent, size)
          end
        end

        stdin.close
        status = wait.value
        raise "transfer failed: #{err.read}" unless status.success?
      end

      @io.puts("\nDone: #{target}")
      target
    end

    REPLACED_DIRS = ["pronunciation/templates"].freeze

    def inspect_remote
      script = "for d in #{REMOTE_DIR}/*; do [ -e \"$d\" ] && printf '%s\\t%s\\n' \"$(du -sh \"$d\" 2>/dev/null | cut -f1)\" \"$d\"; done"
      output = `#{ssh_command(host, script).shelljoin} 2>/dev/null`
      output.lines.map(&:chomp).reject(&:empty?)
    end

    def report_remote
      entries = inspect_remote
      if entries.empty?
        @io.puts("#{REMOTE_DIR} on the server is empty.")
        return
      end

      @io.puts("Currently in #{REMOTE_DIR} on the server:")
      entries.each { |line| @io.puts("  #{line}") }
      @io.puts(
        "\nUnpacking merges: matching files are overwritten, the rest are kept.\n" \
          "#{REPLACED_DIRS.join(", ")} are replaced in full: mixing old and new\n" \
          "files there would invalidate pronunciation scoring."
      )
    end

    def stream(local_dir, replace_dirs: REPLACED_DIRS)
      raise ArgumentError, "no such directory: #{local_dir}" unless File.directory?(local_dir)

      check!
      @io.puts("Streaming the contents of #{local_dir} into #{REMOTE_DIR}")

      moves = replace_dirs.map do |dir|
        path = File.join(REMOTE_DIR, dir)
        "if [ -d #{path.shellescape} ]; then rm -rf #{"#{path}.old".shellescape}; " \
          "mv #{path.shellescape} #{"#{path}.old".shellescape}; fi"
      end

      cleanup = replace_dirs.map { |dir| "rm -rf #{File.join(REMOTE_DIR, "#{dir}.old").shellescape}" }

      remote = [
        "set -e",
        *moves,
        "tar -xzf - -C #{REMOTE_DIR.shellescape}",
        *cleanup
      ].join("; ")

      tar = ["tar", "-czf", "-", "-C", local_dir.to_s, "."]
      tar_err = ""
      ssh_err = ""

      Open3.popen3({"COPYFILE_DISABLE" => "1"}, *tar) do |tar_in, tar_out, tar_e, tar_wait|
        tar_in.close
        tar_out.binmode

        Open3.popen3(*ssh_command(host, remote)) do |ssh_in, _ssh_out, ssh_e, ssh_wait|
          ssh_in.binmode
          IO.copy_stream(tar_out, ssh_in)
          ssh_in.close

          ssh_err = ssh_e.read
          tar_err = tar_e.read
          tar_status = tar_wait.value
          ssh_status = ssh_wait.value

          unless tar_status.success? && ssh_status.success?
            message = [ssh_err, tar_err].map(&:strip).reject(&:empty?).join(" | ")
            raise "transfer failed (#{message.presence || "no output"})"
          end
        end
      end

      @io.puts("Transferred and unpacked.")
    end

    def unpack(remote_path)
      @io.puts("Unpacking #{remote_path}…")

      moves = REPLACED_DIRS.map do |dir|
        path = File.join(REMOTE_DIR, dir)
        "if [ -d #{path.shellescape} ]; then rm -rf #{"#{path}.old".shellescape}; mv #{path.shellescape} #{"#{path}.old".shellescape}; fi"
      end

      cleanup = REPLACED_DIRS.map { |dir| "rm -rf #{File.join(REMOTE_DIR, "#{dir}.old").shellescape}" }

      script = [
        "set -e",
        *moves,
        "tar -xzf #{remote_path.shellescape} -C #{REMOTE_DIR.shellescape}",
        *cleanup,
        "rm -f #{remote_path.shellescape}",
        "du -sh #{REMOTE_DIR.shellescape}/* 2>/dev/null | head -20"
      ].join("; ")

      ok = system(*ssh_command(host, script))
      unless ok
        raise "unpacking failed, the previous directories are left as *.old"
      end

      @io.puts("Unpacked.")
    end

    SYNC_ATTEMPTS = 3

    def sync_dir(local_dir, remote_subdir)
      local = Pathname(local_dir)
      raise ArgumentError, "no such directory: #{local}" unless local.directory?

      sync_paths(["#{local}/"], remote_subdir)
    end

    def ensure_dirs(subdirs)
      nested = Array(subdirs).select { |subdir| subdir.to_s.include?("/") }
      return if nested.empty?

      paths = nested.map { |subdir| File.join(REMOTE_DIR, subdir).shellescape }
      @io.puts("→ creating on the server: #{nested.join(", ")}")
      run_remote("mkdir -p #{paths.join(" ")}")
    end

    def sync_paths(sources, remote_subdir, dry_run: false, checksum: false)
      raise ArgumentError, "nothing to sync into #{remote_subdir}" if sources.blank?

      target = "#{File.join(REMOTE_DIR, remote_subdir).chomp("/")}/"
      @io.puts(
        "→ #{dry_run ? "listing without transfer" : "syncing"}: #{sources.length} source(s) → #{host}:#{target}"
      )

      attempt = 0
      begin
        attempt += 1
        rsync!(sources, target, dry_run:, checksum:)
      rescue => error
        raise if attempt >= SYNC_ATTEMPTS

        pause = attempt * 10
        @io.puts(
          "  ↻ attempt #{attempt} failed (#{error.message}); retrying in #{pause}s"
        )
        sleep(pause)
        retry
      end
    end

    def rsync_command(sources, target, dry_run: false, checksum: false)
      [
        "rsync",
        "-rltvz",
        "--no-perms",
        "--no-owner",
        "--no-group",
        "--omit-dir-times",
        "--partial",
        "--stats",
        *("--dry-run" if dry_run),
        *("--checksum" if checksum),
        "-e",
        (["ssh"] + SSH_OPTIONS).join(" "),
        *sources.map(&:to_s),
        "#{host}:#{target}"
      ]
    end

    def rsync!(sources, target, dry_run: false, checksum: false)
      command = rsync_command(sources, target, dry_run:, checksum:)

      status = nil
      Open3.popen2e(*command) do |stdin, out, wait|
        stdin.close
        out.each_line do |line|
          @io.print("  #{line}")
          @io.flush
        end

        status = wait.value
      end

      raise "rsync failed (exit #{status.exitstatus})" unless status.success?
    end

    def run_remote(command)
      @io.puts("→ connecting to #{host} …")
      check!
      @io.puts("→ running on the server:")
      command.split("; ").each { |part| @io.puts("    #{part.strip}") }
      @io.puts("  ┄┄ server output ┄┄")

      login = ["bash", "-lc", command].shelljoin
      status = nil
      Open3.popen2e(*ssh_command(host, login)) do |stdin, out, wait|
        stdin.close
        out.each_line do |line|
          @io.print("  │ #{line}")
          @io.flush
        end

        status = wait.value
      end

      @io.puts("  ┄┄ end of output (exit #{status.exitstatus}) ┄┄")
      unless status.success?
        raise "the remote command failed (exit #{status.exitstatus})"
      end
    end

    private

    def check!
      out, err, status = Open3.capture3(*ssh_command(host, "test -d #{REMOTE_DIR} && echo ok"))
      return if status.success? && out.include?("ok")

      reason = err.to_s.strip.presence || "exit #{status.exitstatus}"
      raise(
        "could not connect to #{host}, or #{REMOTE_DIR} is missing there:\n  #{reason}"
      )
    end

    def ssh_command(target, remote)
      ["ssh", *SSH_OPTIONS, target, remote]
    end

    def progress(sent, total)
      share = sent.to_f / total
      filled = (share * 24).round
      @io.print("\r  [#{"#" * filled}#{"." * (24 - filled)}] #{(share * 100).round}%  #{human(sent)}")
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
