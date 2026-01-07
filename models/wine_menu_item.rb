class WineMenuItem < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :wine_menu, key: :menu_id
  one_to_one :enriched_wine_menu_item

  def validate
    super
    errors.add(:category, 'invalid category') if category && !Enums::WineCategory.valid?(category)
  end

  def to_api_hash
    enrichment = enriched_wine_menu_item

    {
      id: id,
      name: name,
      price_glass: price_glass,
      price_bottle: price_bottle,
      category: category,
      grape_varietal: enrichment&.grape_varietal,
      description: enrichment&.description,
      country: enrichment&.country,
      region: enrichment&.region,
      flavor: enrichment&.flavor,
      created_at: created_at&.iso8601
    }
  end
end
