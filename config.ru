require './app'

# Enable pry-rescue in development to catch unhandled exceptions
if ENV['RACK_ENV'] != 'production'
  require 'pry-rescue'
  use PryRescue::Rack
end

run AiLaCarteApp
