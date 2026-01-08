class EnrichedFoodMenuItem < Sequel::Model
  unrestrict_primary_key
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :food_menu_item

  def tags_array
    return [] if tags.nil?

    case tags
    when Array
      tags
    when String
      JSON.parse(tags)
    else
      tags.to_a
    end
  rescue JSON::ParserError
    []
  end

  def to_api_hash
    {
      food_menu_item_id: food_menu_item_id,
      description: description,
      tags: tags_array,
      created_at: created_at&.iso8601
    }
  end
end
