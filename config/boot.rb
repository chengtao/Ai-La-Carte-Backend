# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default, ENV.fetch('RACK_ENV', 'development').to_sym)

require 'dotenv/load' unless ENV['RACK_ENV'] == 'production'

# Database connection
require_relative 'database'

# Constants (must be loaded before lib files that may use them)
require_relative 'constants'

# Load lib files
Dir[File.join(__dir__, '..', 'lib', '**', '*.rb')].sort.each { |f| require f }

# Load models
Dir[File.join(__dir__, '..', 'models', '*.rb')].sort.each { |f| require f }

# Load clients
Dir[File.join(__dir__, '..', 'clients', '*.rb')].sort.each { |f| require f }

# Load services
Dir[File.join(__dir__, '..', 'services', '*.rb')].sort.each { |f| require f }

# Controllers are loaded by app.rb
