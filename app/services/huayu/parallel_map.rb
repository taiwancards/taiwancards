# frozen_string_literal: true

module Huayu
  module ParallelMap
    module_function

    def cores = [Install::Hardware.performance_cores, 1].max

    def workers(requested = nil)
      value = (requested || ENV["WORKERS"]).to_i
      value.positive? ? value : cores
    end

    def call(items, workers: nil, warmup: nil, &block)
      pool = [workers(workers), items.length].min
      return items.map(&block) if pool <= 1 || items.length < 256

      warmup&.call

      slices = items.each_slice((items.length / pool.to_f).ceil).to_a
      readers = []

      slices.each do |slice|
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          writer.binmode
          ActiveRecord::Base.connection_handler.clear_active_connections!
          payload = Marshal.dump(slice.map(&block))
          writer.write([payload.bytesize].pack("Q"))
          writer.write(payload)
          writer.close
          exit!(0)
        end

        writer.close
        readers << [pid, reader]
      end

      results = readers.map do |_, reader|
        reader.binmode
        header = reader.read(8)
        size = header ? header.unpack1("Q") : 0
        body = size.positive? ? reader.read(size) : nil
        reader.close
        body ? Marshal.load(body) : []
      end

      readers.each { |pid, _| Process.waitpid(pid) }
      results.flatten(1)
    end
  end
end
