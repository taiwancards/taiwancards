# frozen_string_literal: true

module RakeProgress
  BAR_WIDTH = 24

  module_function

  def sync!
    $stdout.sync = true
    $stderr.sync = true
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def duration(seconds)
    return "#{(seconds * 1000).round} ms" if seconds < 1
    return "#{seconds.round(1)} s" if seconds < 60

    "#{(seconds / 60).floor} m #{(seconds % 60).round} s"
  end

  def banner(title, steps)
    sync!
    puts("")
    puts("═" * 60)
    puts("  #{title}  (#{steps} steps)")
    puts("═" * 60)
  end

  def step(index, total, name)
    sync!
    started = clock
    puts("")
    puts("▸ [#{index}/#{total}] #{name}")
    result = yield
    puts("  ✓ #{name} — #{duration(clock - started)}")
    result
  rescue => e
    puts("  ✗ #{name} — #{e.class}: #{e.message}")
    raise
  end

  def report(result)
    sync!
    case result
    when Hash
      result.each { |key, value| puts("    #{key}: #{value}") }
    when Numeric
      puts("    #{result}")
    when nil
      nil
    else
      puts("    #{result}")
    end

    result
  end

  def counter(total, label, every: 500)
    sync!
    started = clock
    done = 0
    live = $stdout.tty?
    stride = live ? every : [(total / 10.0).ceil, every].max

    tick = lambda do
      done += 1
      return unless (done % stride).zero? || done == total

      elapsed = clock - started
      rate = elapsed.positive? ? (done / elapsed).round : 0
      line = "    #{bar(done, total)} #{done}/#{total} #{label} — #{rate}/s"
      live ? print("\r#{line}   ") : puts(line)
    end

    yield(tick)
    puts("") if live
    done
  end

  def tick(done, total, label)
    sync!
    live = $stdout.tty?
    stride = live ? 1 : [(total / 10.0).ceil, 1].max
    return unless (done % stride).zero? || done == total

    line = "    #{bar(done, total)} #{done}/#{total} #{label}"
    live ? print("\r#{line}   ") : puts(line)
    puts("") if live && done == total
  end

  def bar(done, total)
    return "" if total.to_i <= 0

    filled = (BAR_WIDTH * done / total.to_f).round.clamp(0, BAR_WIDTH)
    "[#{"█" * filled}#{"·" * (BAR_WIDTH - filled)}]"
  end

  def finish(title, started)
    sync!
    puts("")
    puts("═" * 60)
    puts("  #{title} — done in #{duration(clock - started)}")
    puts("═" * 60)
  end

  HEARTBEAT = 15

  def pipeline(steps, offset: 0, total: nil)
    sync!
    timings = []
    total ||= steps.length

    steps.each_with_index do |(name, title), index|
      started = clock
      puts("")
      puts("══ [#{offset + index + 1}/#{total}] #{title} " + "═" * [1, 54 - title.length].max)
      heartbeat(started) { yield(name, title) }
      spent = clock - started
      timings << [title, spent]
      puts("   ✓ #{title} — #{duration(spent)}")
    rescue Interrupt, StandardError => e
      puts("   ✗ #{title} — #{e.class}: #{e.message}")
      raise
    end

    timings
  end

  def heartbeat(started, every: HEARTBEAT)
    return yield unless $stdout.tty?

    ticker = Thread.new do
      loop do
        sleep(every)
        print("\r   … working, #{duration(clock - started)}   ")
        $stdout.flush
      end
    end

    yield
  ensure
    if ticker
      ticker.kill
      ticker.join
      print("\r#{" " * 40}\r")
    end
  end

  def slowest(timings, take: 8)
    return if timings.blank?

    sync!
    ranked = timings.sort_by { |_, spent| -spent }.first(take)
    width = ranked.map { |title, _| title.length }.max
    puts("")
    puts("slowest steps")
    ranked.each { |title, spent| puts("  #{title.ljust(width)}  #{duration(spent)}") }
  end

  def tuning_report(settings)
    sync!
    puts("")
    puts(
      "postgres session: #{settings[:parallel_workers]} parallel workers, " \
        "work_mem #{settings[:work_mem]}, maintenance_work_mem #{settings[:maintenance_work_mem]}"
    )
    return unless settings[:capped_by_server]

    puts(
      "  note: max_worker_processes = #{settings[:max_worker_processes]} caps parallelism " \
        "below the #{settings[:cores]} cores available."
    )
    puts("  raise it in postgresql.conf and restart to use more of the machine.")
  end
end
