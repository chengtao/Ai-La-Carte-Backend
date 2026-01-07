# frozen_string_literal: true

class JobRunner
  class << self
    def run_async(job, logger: nil)
      logger ||= Logger.new($stdout)

      Thread.new do
        AsyncMenuCreationService.new(job: job, logger: logger).execute
      rescue StandardError => e
        # Job status already updated in service
        logger.error "Job #{job.uuid} failed: #{e.message}"
      end
    end
  end
end
