require 'bundler/setup'
Bundler.require(:default, ENV.fetch('RACK_ENV', 'development').to_sym)

require 'dotenv/load' unless ENV['RACK_ENV'] == 'production'

# Database connection
require_relative 'database'

# Load lib files
Dir[File.join(__dir__, '..', 'lib', '**', '*.rb')].sort.each { |f| require f }

# Load models
Dir[File.join(__dir__, '..', 'models', '*.rb')].sort.each { |f| require f }

# Load clients
Dir[File.join(__dir__, '..', 'clients', '*.rb')].sort.each { |f| require f }

# Load services
Dir[File.join(__dir__, '..', 'services', '*.rb')].sort.each { |f| require f }

# Load controllers (base_controller first, then others alphabetically)
require File.join(__dir__, '..', 'controllers', 'base_controller.rb')
Dir[File.join(__dir__, '..', 'controllers', '*.rb')].sort.each do |f|
  require f unless f.end_with?('base_controller.rb')
end
