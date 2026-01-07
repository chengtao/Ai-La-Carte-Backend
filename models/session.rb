class Session < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  one_to_one :review

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

  def photo_urls_array
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
      id: id,
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
