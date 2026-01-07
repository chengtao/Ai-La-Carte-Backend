class EnrichedWineMenuItem < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :wine_menu_item

  def validate
    super
    errors.add(:flavor, 'invalid flavor') if flavor && !Enums::WineFlavor.valid?(flavor)
  end

  def to_api_hash
    {
      wine_menu_item_id: wine_menu_item_id,
      grape_varietal: grape_varietal,
      description: description,
      country: country,
      region: region,
      flavor: flavor,
      created_at: created_at&.iso8601
    }
  end
end
