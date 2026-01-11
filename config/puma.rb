workers Integer(ENV.fetch('WEB_CONCURRENCY', 2))
threads_count = Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
threads threads_count, threads_count

preload_app!

port ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')

# Disconnect database connections before forking workers
# This is critical to avoid sharing connections across processes
before_fork do
  if defined?(DB)
    DB.disconnect
    puts "Puma master: Disconnected database connections before fork"
  end
end

# Reconnect after fork - each worker gets its own connection pool
on_worker_boot do
  if defined?(DB)
    # Force disconnect any inherited connections
    DB.disconnect

    # Test the connection to ensure pool is working
    DB.test_connection
    puts "Puma worker #{Process.pid}: Database connection pool ready"
  end
end
