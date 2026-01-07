# frozen_string_literal: true

require_relative 'config/boot'
require_relative 'controllers/base_controller'
require_relative 'controllers/ics_controller'
require_relative 'controllers/api_controller'


class AiLaCarteApp < Sinatra::Base
  # Session configuration - MUST be before controllers to share session
  use Rack::Session::Cookie,
      key: 'ai_la_carte.session',
      secret: ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) },
      expire_after: 86_400 * 7 # 1 week

  # Mount modular controllers as middleware (after session setup)
  use IcsController
  use ApiController

  configure do
    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, 'views')
    set :public_folder, File.join(settings.root, 'public')
    set :haml, format: :html5
  end

  configure :development do
    register Sinatra::Reloader
  end

  # Root redirect
  get '/' do
    redirect '/ics/home'
  end

  # Health check endpoint
  get '/health' do
    content_type :json
    { status: 'ok', timestamp: Time.now.utc.iso8601 }.to_json
  end
end
