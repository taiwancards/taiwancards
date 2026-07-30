# frozen_string_literal: true

module Install
  class Console
    WIDTH = 76
    BAR = 30

    COLORS = {
      bold: "\e[1m",
      dim: "\e[2m",
      green: "\e[32m",
      red: "\e[31m",
      yellow: "\e[33m",
      cyan: "\e[36m",
      reset: "\e[0m"
    }.freeze

    def initialize(io: $stdout)
      @io = io
      @io.sync = true
      @color = io.tty?
      @started = clock
    end

    def paint(text, color)
      return text.to_s unless @color

      "#{COLORS.fetch(color)}#{text}#{COLORS.fetch(:reset)}"
    end

    def rule = @io.puts(paint("=" * WIDTH, :dim))

    def title(text)
      @io.puts(paint(text, :bold))
    end

    def phase(index, total, text)
      @io.puts("")
      rule
      @io.puts("#{paint(bar(index, total), :bold)}  #{paint(text, :bold)}")
      @io.puts(paint("#{"=" * WIDTH}  elapsed #{elapsed}", :dim))
    end

    def step(text)
      @io.print("  #{paint("→", :cyan)} #{text.to_s.ljust(46)}")
      began = clock
      result = yield
      @io.puts("#{paint("✓", :green)} #{duration(clock - began)}")
      result
    rescue StandardError => e
      @io.puts(paint("✗", :red))
      raise e
    end

    def ok(text) = @io.puts("  #{paint("✓", :green)} #{text}")

    def warn(text) = @io.puts("  #{paint("!", :yellow)} #{text}")

    def note(text) = @io.puts(paint("  #{text}", :dim))

    def line(text) = @io.puts("  #{text}")

    def progress(total, label)
      return yield(-> (*) { }) if total.to_i.zero?

      done = 0
      began = clock
      stride = @color ? 200 : [(total / 20.0).ceil, 200].max

      tick = lambda do |count = 1|
        done += count
        next unless (done % stride) < count || done >= total

        render(done, total, label, clock - began)
      end

      result = yield(tick)
      render(total, total, label, clock - began)
      @io.puts("")
      result
    end

    def table(rows, widths)
      rows.each do |row|
        @io.puts("  " + row.each_with_index.map { |cell, i| cell.to_s.ljust(widths[i]) }.join(" ").rstrip)
      end
    end

    def elapsed = duration(clock - @started)

    def duration(seconds)
      return "#{(seconds * 1000).round} ms" if seconds < 1
      return format("%.1f s", seconds) if seconds < 60

      format("%d:%02d", (seconds / 60).floor, (seconds % 60).round)
    end

    private

    def render(done, total, label, spent)
      rate = spent.positive? ? (done / spent).round : 0
      eta = rate.positive? ? duration((total - done) / rate.to_f) : "—"
      text = "    #{bar(done, total)} #{done}/#{total} #{label} · #{rate}/s · eta #{eta}"
      @color ? @io.print("\r#{text.ljust(WIDTH)}") : @io.puts(text)
    end

    def bar(done, total)
      filled = total.zero? ? 0 : (done * BAR / total)
      "[#{"#" * filled}#{"." * (BAR - filled)}]"
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
