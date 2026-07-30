# frozen_string_literal: true

module Install
  module SessionTuning
    RESERVED_CORES = 2
    MAX_WORK_MEM_MB = 2048
    MAX_MAINTENANCE_MEM_MB = 16_384
    WORK_MEM_SHARE = 0.02
    MAINTENANCE_MEM_SHARE = 0.10

    module_function

    def apply!(connection = ActiveRecord::Base.connection)
      settings(connection).each { |name, value| connection.execute("SET #{name} = #{value}") }
    end

    def settings(connection = ActiveRecord::Base.connection)
      workers = gather_workers(connection)

      {
        "work_mem" => quote("#{work_mem_mb}MB"),
        "maintenance_work_mem" => quote("#{maintenance_work_mem_mb}MB"),
        "max_parallel_workers" => worker_ceiling(connection),
        "max_parallel_workers_per_gather" => workers,
        "max_parallel_maintenance_workers" => workers,
        "synchronous_commit" => "off",
        "jit" => "off"
      }
    end

    def report(connection = ActiveRecord::Base.connection)
      ceiling = worker_ceiling(connection)
      usable = ceiling + 1
      {
        cores: Hardware.cores,
        parallel_workers: gather_workers(connection),
        work_mem: "#{work_mem_mb}MB",
        maintenance_work_mem: "#{maintenance_work_mem_mb}MB",
        capped_by_server: usable < Hardware.performance_cores,
        max_worker_processes: max_worker_processes(connection)
      }
    end

    def work_mem_mb
      share = (Hardware.memory_bytes * WORK_MEM_SHARE / 1024 / 1024).to_i
      share.clamp(64, MAX_WORK_MEM_MB)
    end

    def maintenance_work_mem_mb
      share = (Hardware.memory_bytes * MAINTENANCE_MEM_SHARE / 1024 / 1024).to_i
      share.clamp(64, MAX_MAINTENANCE_MEM_MB)
    end

    def gather_workers(connection = ActiveRecord::Base.connection)
      wanted = [Hardware.performance_cores - RESERVED_CORES, 1].max
      [wanted, worker_ceiling(connection)].min
    end

    def worker_ceiling(connection = ActiveRecord::Base.connection)
      [max_worker_processes(connection), 1].max
    end

    def max_worker_processes(connection = ActiveRecord::Base.connection)
      connection.select_value("SHOW max_worker_processes").to_i
    end

    def quote(value) = ActiveRecord::Base.connection.quote(value)
  end
end
