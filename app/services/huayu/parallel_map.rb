# frozen_string_literal: true

module Huayu
  module ParallelMap
    Error = Class.new(StandardError)

    module_function

    def cores = [Install::Hardware.performance_cores, 1].max

    def forkable? = Process.respond_to?(:fork) && !RUBY_PLATFORM.include?("darwin")

    def workers(requested = nil)
      value = (requested || ENV["WORKERS"]).to_i
      value.positive? ? value : cores
    end

    def call(items, workers: nil, warmup: nil, &block)
      pool = [workers(workers), items.length].min
      return items.map(&block) if pool <= 1 || items.length < 256 || !forkable?

      warmup&.call
      release_connections

      slices = items.each_slice((items.length / pool.to_f).ceil).to_a
      readers = slices.map { |slice| spawn_worker(slice, &block) }

      collect(readers)
    end

    def spawn_worker(slice, &block)
      reader, writer = IO.pipe

      pid = fork do
        reader.close
        writer.binmode
        payload = Marshal.dump(slice.map(&block))
        writer.write([payload.bytesize].pack("Q"))
        writer.write(payload)
        writer.close
        exit!(0)
      end

      writer.close
      [pid, reader]
    end

    def collect(readers)
      results = readers.map { |_, reader| receive(reader) }
      statuses = readers.map { |pid, _| Process.waitpid2(pid).last }
      lost = statuses.each_index.count { |index| results[index].nil? || !statuses[index].success? }
      raise Error, "#{lost} of #{readers.length} workers died; rerun with WORKERS=1" if lost.positive?

      results.flatten(1)
    end

    def receive(reader)
      reader.binmode
      header = reader.read(8)
      size = header&.bytesize == 8 ? header.unpack1("Q") : 0
      body = size.positive? ? reader.read(size) : nil
      reader.close

      body&.bytesize == size ? Marshal.load(body) : nil
    end

    def release_connections
      handler = ActiveRecord::Base.connection_handler
      handler.clear_active_connections!
      handler.connection_pool_list(:all).each(&:disconnect!)
    end
  end
end
