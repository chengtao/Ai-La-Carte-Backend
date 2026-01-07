class Restaurant < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :food_menu
  many_to_one :wine_menu

  dataset_module do
    def search(query)
      where(
        Sequel.ilike(:name, "%#{query}%") |
        Sequel.ilike(:address, "%#{query}%")
      )
    end

    def near(lat, lng, radius_km = 5)
      distance_sql = Sequel.lit(
        '(6371 * acos(cos(radians(?)) * cos(radians(lat)) * cos(radians(lng) - radians(?)) + sin(radians(?)) * sin(radians(lat))))',
        lat, lng, lat
      )
      where(Sequel.lit('lat IS NOT NULL AND lng IS NOT NULL'))
        .where(distance_sql < radius_km)
        .order(distance_sql)
    end
  end

  def before_save
    self.last_updated_at = Time.now
    super
  end

  def to_api_hash
    {
      id: id,
      name: name,
      address: address,
      cuisine: cuisine,
      lat: lat,
      lng: lng,
      latest_food_menu_id: food_menu_id,
      latest_wine_menu_id: wine_menu_id,
      menu_updated_at: menu_updated_at&.iso8601,
      created_at: created_at&.iso8601,
      last_updated_at: last_updated_at&.iso8601
    }
  end

  def to_api_hash_with_menus
    to_api_hash.merge(
      food_menu: food_menu&.to_api_hash,
      wine_menu: wine_menu&.to_api_hash
    )
  end
end
