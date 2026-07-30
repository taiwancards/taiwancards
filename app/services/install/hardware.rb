# frozen_string_literal: true

require "etc"

module Install
  module Hardware
    module_function

    def cores = Etc.nprocessors

    def perflevels
      return [] unless macos?

      count = sysctl("hw.nperflevels").to_i
      (0...count).map do |index|
        [sysctl("hw.perflevel#{index}.name"), sysctl("hw.perflevel#{index}.physicalcpu").to_i]
      end
    end

    def performance_cores
      levels = perflevels
      return cores if levels.empty?

      fast = levels.reject { |name, _| name.casecmp?("Efficiency") }.sum { |_, count| count }
      fast.positive? ? fast : cores
    end

    def efficiency_cores
      perflevels.select { |name, _| name.casecmp?("Efficiency") }.sum { |_, count| count }
    end

    def memory_bytes
      return sysctl("hw.memsize").to_i if macos?

      File.read("/proc/meminfo")[/MemTotal:\s+(\d+)/, 1].to_i * 1024
    rescue StandardError
      0
    end

    def chip
      return sysctl("machdep.cpu.brand_string") if macos?

      File.read("/proc/cpuinfo")[/model name\s*:\s*(.+)/, 1].to_s.strip
    rescue StandardError
      "unknown"
    end

    def macos? = RbConfig::CONFIG["host_os"].include?("darwin")

    def platform = macos? ? "macOS #{sysctl("kern.osproductversion")}" : RbConfig::CONFIG["host_os"]

    def workers = [performance_cores, 1].max

    def maintenance_workers = [[performance_cores, 16].min, 1].max

    def sysctl(key)
      `sysctl -n #{key} 2>/dev/null`.strip
    rescue StandardError
      ""
    end

    def report(io)
      io.puts("  #{chip}")
      io.puts(
        format(
          "  %s · %d cores (%s) · %.0f GB RAM",
          platform,
          cores,
          perflevels.map { |name, count| "#{count} #{name.downcase}" }.join(" + ").presence || "uniform",
          memory_bytes / 1024.0 ** 3
        )
      )
      io.puts("  parallel workers: #{workers}, postgres maintenance workers: #{maintenance_workers}")
    end
  end
end
