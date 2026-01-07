require 'dotenv/load' unless ENV['RACK_ENV'] == 'production'
require 'sequel'

namespace :db do
  desc 'Run database migrations'
  task :migrate do
    require_relative 'config/database'
    Sequel.extension :migration
    Sequel::Migrator.run(DB, 'db/migrations')
    puts 'Migrations completed successfully'
  end

  desc 'Rollback the last migration'
  task :rollback do
    require_relative 'config/database'
    Sequel.extension :migration
    version = DB[:schema_migrations].order(Sequel.desc(:filename)).first
    if version
      target = version[:filename].to_i - 1
      Sequel::Migrator.run(DB, 'db/migrations', target: target)
      puts "Rolled back to version #{target}"
    else
      puts 'No migrations to rollback'
    end
  end

  desc 'Create the database'
  task :create do
    database_url = ENV.fetch('DATABASE_URL')
    db_name = database_url.split('/').last
    system("createdb #{db_name}")
    puts "Database #{db_name} created"
  end

  desc 'Drop the database'
  task :drop do
    database_url = ENV.fetch('DATABASE_URL')
    db_name = database_url.split('/').last
    system("dropdb #{db_name}")
    puts "Database #{db_name} dropped"
  end

  desc 'Reset the database (drop, create, migrate)'
  task reset: [:drop, :create, :migrate]
end

desc 'Start the development server'
task :server do
  exec 'bundle exec rerun -- puma -C config/puma.rb'
end

task default: :server
