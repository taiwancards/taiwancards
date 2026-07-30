threads_count = ENV.fetch("RAILS_MAX_THREADS", 3).to_i
threads(threads_count, threads_count)

port(ENV.fetch("PORT", 3000))

plugin(:tmp_restart)

pidfile(ENV["PIDFILE"]) if ENV["PIDFILE"]

worker_count = ENV.fetch("WEB_CONCURRENCY", 0).to_i

if worker_count > 1
  workers(worker_count)
  preload_app!

  before_fork { ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord::Base) }
  before_worker_boot { ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base) }
  before_worker_shutdown { ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord::Base) }
  on_worker_boot { Process.warmup }
else
  on_booted { Process.warmup }
end
