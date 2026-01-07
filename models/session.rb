# frozen_string_literal: true

class Session < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  one_to_one :review
  one_to_many :session_photos
  one_to_many :jobs
  one_to_many :feedback_items, class: :Feedback
  many_to_one :food_menu
  many_to_one :wine_menu

  # Class method to find by UUID (for API)
  def self.find_by_uuid(uuid_value)
    where(uuid: uuid_value).first
  end

  # Class method to find or create by UUID
  def self.find_or_create_by_uuid(uuid_value)
    find_by_uuid(uuid_value) || create(uuid: uuid_value)
  end

  def before_create
    self.uuid ||= SecureRandom.uuid
    super
  end

  dataset_module do
    def reviewed
      where(id: Review.select(:session_id))
    end

    def unreviewed
      exclude(id: Review.select(:session_id))
    end
  end

  def reviewed?
    !review.nil?
  end

  # Collect photo URLs from session_photos relation (new way)
  # Falls back to legacy photo_urls JSONB column for backward compatibility
  def photo_urls_array
    # Prefer session_photos if available
    return session_photos.map(&:url) if session_photos.any?

    # Fall back to legacy photo_urls column
    return [] if photo_urls.nil?

    case photo_urls
    when Array
      photo_urls
    when String
      JSON.parse(photo_urls)
    else
      photo_urls.to_a
    end
  rescue JSON::ParserError
    []
  end

  def to_api_hash
    {
      id: uuid,  # Return UUID as the client-facing ID
      photo_urls: photo_urls_array,
      lat: lat,
      lng: lng,
      potential_restaurant_name: potential_restaurant_name,
      potential_address: potential_address,
      reviewed: reviewed?,
      created_at: created_at&.iso8601
    }
  end
end
