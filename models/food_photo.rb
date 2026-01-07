class FoodPhoto < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  dataset_module do
    def search(query)
      where(Sequel.ilike(:standardized_name, "%#{query}%"))
    end
  end

  def to_api_hash
    {
      id: id,
      standardized_name: standardized_name,
      photo_url: photo_url,
      created_at: created_at&.iso8601
    }
  end
end
