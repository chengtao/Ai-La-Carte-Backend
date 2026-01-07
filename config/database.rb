require 'sequel'
require 'logger'

database_url = ENV.fetch('DATABASE_URL') do
  'postgres://localhost/ai_la_carte_development'
end

DB = Sequel.connect(
  database_url,
  max_connections: ENV.fetch('DB_POOL', 5).to_i,
  logger: ENV['RACK_ENV'] == 'development' ? Logger.new($stdout) : nil
)

DB.extension :pg_json
Sequel::Model.plugin :json_serializer
