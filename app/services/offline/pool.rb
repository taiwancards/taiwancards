# frozen_string_literal: true

module Offline
  class Pool
    Error = Class.new(StandardError)
    Child = Struct.new(:pid, :feed, :collect)

    SLICE = 40
    COMMAND = ["bin/rails", "runner", "Offline::Worker.serve(3, 4)"].freeze

    def self.workers(requested = ENV.fetch("WORKERS", nil))
      value = requested.to_i
      value.positive? ? value : Install::Hardware.workers
    end

    def initialize(workers: 1, renderer: Renderer.new, command: COMMAND)
      @workers = [workers.to_i, 1].max
      @renderer = renderer
      @command = command
      @children = []
    end

    attr_reader :workers

    def parallel? = workers > 1

    def render(paths, locale, &progress)
      answers = parallel? ? spread(paths, locale, &progress) : serial(paths, locale, &progress)
      fragments = answers.each_with_object({}) { |answer, acc| acc.merge!(answer.fetch("fragments")) }
      refused = answers.flat_map { |answer| answer.fetch("refused") }
      ordered = paths.each_with_object({}) { |path, acc| acc[path] = fragments[path] if fragments.key?(path) }

      [ordered, refused]
    end

    def close
      children.each { |child| child.feed.close unless child.feed.closed? }
      children.each do |child|
        suppress(Errno::ECHILD) { Process.wait(child.pid) }
        child.collect.close unless child.collect.closed?
      end

      @children = []
    end

    private

    attr_reader :renderer, :command, :children

    def serial(paths, locale)
      worker = Worker.new(renderer:)
      done = 0

      paths.each_slice(SLICE).map do |slice|
        answer = worker.perform(locale.to_s, slice)
        done += slice.size
        yield(done) if block_given?
        answer
      end
    end

    def spread(paths, locale, &progress)
      start
      queue = Queue.new
      paths.each_slice(SLICE) { |slice| queue << slice }
      queue.close
      lock = Mutex.new
      done = 0

      threads = children.map do |child|
        Thread.new do
          Thread.current.report_on_exception = false
          answers = []

          while (slice = queue.pop)
            answers << ask(child, locale.to_s, slice)
            lock.synchronize do
              done += slice.size
              progress&.call(done)
            end
          end

          answers
        end
      end

      collect(threads)
    end

    def collect(threads)
      threads.flat_map(&:value)
    rescue StandardError
      abandon
      threads.each { |thread| suppress(StandardError) { thread.join } }
      raise
    end

    def ask(child, locale, slice)
      Frames.write(child.feed, {"locale" => locale, "paths" => slice})
      Frames.read(child.collect) || raise(Error, lost(child))
    rescue Errno::EPIPE, IOError
      raise Error, lost(child)
    end

    def lost(child) = "offline worker #{child.pid} died; rerun with WORKERS=1"

    def start
      return if children.any?

      @children = Array.new(workers) { spawn }
    end

    def spawn
      to_child, feed = IO.pipe
      collect, from_child = IO.pipe
      pid = Process.spawn(
        {"RAILS_ENV" => Rails.env.to_s},
        *command,
        3 => to_child,
        4 => from_child,
        :out => :err,
        :chdir => Rails.root.to_s
      )
      to_child.close
      from_child.close
      feed.binmode
      collect.binmode

      Child.new(pid, feed, collect)
    end

    def abandon
      children.each { |child| suppress(Errno::ESRCH, Errno::EPERM) { Process.kill("TERM", child.pid) } }
      close
    end
  end
end
