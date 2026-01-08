# frozen_string_literal: true

class JobRunner
  include AppLogger

  class << self
    include AppLogger

    def run_async(job, logger: nil)
      # Use provided logger or fall back to AppLogger
      log = logger || self.logger
      log.info "JobRunner: Starting async execution for job #{job.uuid}"
      log.debug "JobRunner: Job details - session_id: #{job.session_id}, status: #{job.status}"

      thread = Thread.new do
        Thread.current[:name] = "job_#{job.uuid}"
        AppLogger.logger.debug "JobRunner: Background thread started for job #{job.uuid}"

        begin
          AsyncMenuCreationService.new(job: job).execute
          AppLogger.logger.info "JobRunner: Job #{job.uuid} completed successfully"
        rescue StandardError => e
          # Job status already updated in service
          AppLogger.logger.error "JobRunner: Job #{job.uuid} failed with error: #{e.class} - #{e.message}"
          AppLogger.logger.debug "JobRunner: Error backtrace:"
          e.backtrace&.first(5)&.each { |line| AppLogger.logger.debug "  #{line}" }
        end
      end

      log.debug "JobRunner: Thread spawned with id #{thread.object_id}"
      thread
    end
  end
end
