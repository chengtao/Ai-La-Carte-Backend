class WineMenu < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  one_to_many :wine_menu_items, key: :menu_id
  one_to_one :restaurant

  def items_with_enrichment
    wine_menu_items.map(&:to_api_hash)
  end

  def to_api_hash
    {
      id: id,
      items: items_with_enrichment,
      created_at: created_at&.iso8601
    }
  end
end
