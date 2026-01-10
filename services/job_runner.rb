# frozen_string_literal: true

class JobRunner
  include AppLogger

  class << self
    include AppLogger

    def run_async(job, logger: nil)
      # Ensure stdout is synced for thread output
      $stdout.sync = true

      # Use provided logger or fall back to AppLogger
      log = logger || AppLogger.logger
      log.info "JobRunner: Starting async execution for job #{job.uuid}"
      log.debug "JobRunner: Job details - session_id: #{job.session_id}, status: #{job.status}"

      thread = Thread.new do
        Thread.current[:name] = "job_#{job.uuid}"
        Thread.current.report_on_exception = true

        begin
          AppLogger.logger.info "JobRunner: Background thread started for job #{job.uuid}"

          # Reload job to ensure fresh data
          job.reload
          AppLogger.logger.debug "JobRunner: Job reloaded, starting service execution"

          AsyncMenuCreationService.new(job: job).execute
          AppLogger.logger.info "JobRunner: Job #{job.uuid} completed successfully"
        rescue StandardError => e
          # Job status already updated in service
          AppLogger.logger.error "JobRunner: Job #{job.uuid} failed with error: #{e.class} - #{e.message}"
          AppLogger.logger.error "JobRunner: Error backtrace:"
          e.backtrace&.first(10)&.each { |line| AppLogger.logger.error "  #{line}" }

          # Ensure job is marked as failed
          begin
            job.update(status: 'failed', error_message: e.message, completed_at: Time.now)
          rescue StandardError => update_err
            AppLogger.logger.error "JobRunner: Failed to update job status: #{update_err.message}"
          end
        end
      end

      # Set thread to abort on exception so we see errors
      thread.abort_on_exception = false

      log.debug "JobRunner: Thread spawned with id #{thread.object_id}"
      thread
    end
  end
end
