class FoodMenuItem < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :food_menu, key: :menu_id
  one_to_one :enriched_food_menu_item

  def validate
    super
    errors.add(:category, 'invalid category') if category && !Enums::FoodCategory.valid?(category)
    errors.add(:spice, 'must be between 1-5') if spice && !(1..5).cover?(spice)
    errors.add(:richness, 'must be between 1-5') if richness && !(1..5).cover?(richness)
  end

  def ingredients_array
    return [] if ingredients.nil?

    case ingredients
    when Array
      ingredients
    when String
      JSON.parse(ingredients)
    else
      ingredients.to_a
    end
  rescue JSON::ParserError
    []
  end

  def food_photo
    return nil unless standardized_name

    FoodPhoto.where(standardized_name: standardized_name).first
  end

  def to_api_hash
    enrichment = enriched_food_menu_item
    photo = food_photo

    {
      id: id,
      name: name,
      standardized_name: standardized_name,
      price: price,
      category: category,
      spice: spice,
      richness: richness,
      ingredients: ingredients_array,
      description: enrichment&.description,
      tags: enrichment&.tags_array || [],
      photo_url: photo&.photo_url,
      created_at: created_at&.iso8601
    }
  end
end
