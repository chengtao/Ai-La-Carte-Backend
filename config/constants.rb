# frozen_string_literal: true

module Constants
  module Pagination
    SESSIONS_LIMIT = 50
    RESTAURANTS_LIMIT = 100
    API_DEFAULT_LIMIT = 50
    PHOTOS_LIMIT = 100
  end

  module Auth
    ICS_USERNAME = ENV.fetch('ICS_USERNAME', 'office').freeze
    ICS_PASSWORD = ENV.fetch('ICS_PASSWORD') { raise 'ICS_PASSWORD environment variable must be set' }.freeze
  end
end
