# frozen_string_literal: true

require 'logger'

module AppLogger
  def self.logger
    @logger ||= Logger.new($stdout).tap do |log|
      log.level = ENV['RACK_ENV'] == 'production' ? Logger::INFO : Logger::DEBUG
      log.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
    end
  end

  def logger
    AppLogger.logger
  end
end
