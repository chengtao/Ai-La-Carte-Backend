# frozen_string_literal: true

class Job < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :session
  many_to_one :food_menu
  many_to_one :wine_menu

  STATUSES = %w[created uploading_photos parsing_menu collecting_reviews building_profile ranking done failed].freeze

  def before_create
    self.uuid ||= SecureRandom.uuid
    super
  end

  def validate
    super
    errors.add(:status, 'invalid status') unless STATUSES.include?(status)
  end

  def update_status(new_status, progress: nil)
    updates = { status: new_status, updated_at: Time.now }
    updates[:progress] = progress if progress
    updates[:started_at] = Time.now if new_status != 'created' && started_at.nil?
    updates[:completed_at] = Time.now if %w[done failed].include?(new_status)
    update(updates)
  end

  def to_api_hash
    {
      job_id: uuid,
      status: status,
      progress: progress
    }
  end
end
