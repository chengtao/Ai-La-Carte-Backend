require_relative 'config/boot'

class AiLaCarteApp < Sinatra::Base
  # Use Rack's cookie session directly to avoid encryption key issues
  use Rack::Session::Cookie,
      key: 'ai_la_carte.session',
      secret: ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) },
      expire_after: 86400 * 7 # 1 week

  configure do
    set :root, File.dirname(__FILE__)
    set :views, File.join(settings.root, 'views')
    set :public_folder, File.join(settings.root, 'public')
    set :haml, format: :html5
    disable :sessions # Disable Sinatra's built-in session handling
  end

  configure :development do
    register Sinatra::Reloader
  end

  # Mount controllers
  use ApiController
  use IcsController

  get '/' do
    redirect '/ics/home'
  end

  # Health check endpoint
  get '/health' do
    content_type :json
    { status: 'ok', timestamp: Time.now.utc.iso8601 }.to_json
  end
end
