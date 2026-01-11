require 'sequel'
require 'logger'

database_url = ENV.fetch('DATABASE_URL') do
  'postgres://localhost/ai_la_carte_development'
end

# Calculate pool size based on threads + background workers
base_pool_size = ENV.fetch('DB_POOL', 10).to_i

DB = Sequel.connect(
  database_url,
  max_connections: base_pool_size,
  pool_timeout: 10,
  single_threaded: false,
  logger: ENV['RACK_ENV'] == 'development' ? Logger.new($stdout) : nil
)

DB.extension :pg_json
Sequel::Model.plugin :json_serializer
