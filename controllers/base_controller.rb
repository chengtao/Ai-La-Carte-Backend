require 'sinatra/base'
require 'sinatra/json'

class BaseController < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', 'views')
    set :haml, format: :html5
  end

  helpers do
    def json_params
      @json_params ||= begin
        body = request.body.read
        return {} if body.empty?

        JSON.parse(body, symbolize_names: true)
      end
    rescue JSON::ParserError
      halt 400, json(error: 'Invalid JSON')
    end

    def current_user
      session[:user]
    end

    def authenticated?
      !current_user.nil?
    end

    def require_auth!
      halt 401, json(error: 'Unauthorized') unless authenticated?
    end

    def json_response(data, status: 200)
      content_type :json
      status status
      data.to_json
    end

    def json_error(message, status: 400)
      content_type :json
      halt status, { error: message }.to_json
    end

    def not_found_error(resource = 'Resource')
      json_error("#{resource} not found", status: 404)
    end
  end

  error Sequel::ValidationFailed do |e|
    content_type :json
    status 422
    { error: 'Validation failed', details: e.errors }.to_json
  end

  error Sequel::NoMatchingRow do
    content_type :json
    status 404
    { error: 'Resource not found' }.to_json
  end
end
