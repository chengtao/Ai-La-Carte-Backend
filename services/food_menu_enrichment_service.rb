class FoodMenuEnrichmentService
  class EnrichmentError < StandardError; end

  ENRICHMENT_PROMPT = <<~PROMPT.freeze
    For each food item, provide enrichment data:

    - standardized_name: A canonical, standardized name for this dish type that can be used across restaurants
      (e.g., "Pad Thai", "Caesar Salad", "Margherita Pizza"). This should be a well-known dish name.
    - description: A 1-2 sentence appetizing description of the dish
    - tags: Array of applicable tag codes from: COMMUNITY_FAVORITE, CHEF_SIGNATURE, CROWD_PLEASER, GREAT_VALUE

    Guidelines for tags:
    - COMMUNITY_FAVORITE: Classic popular dishes that many people love
    - CHEF_SIGNATURE: Unique, upscale, or specialty preparations
    - CROWD_PLEASER: Broadly appealing comfort foods, safe choices for groups
    - GREAT_VALUE: Good portion/quality relative to price

    Consider the dish name, price, category, and ingredients when making these determinations.

    Return JSON with this exact structure:
    {
      "items": [
        {
          "standardized_name": "string",
          "description": "string",
          "tags": ["string"]
        }
      ]
    }

    The items array MUST be in the same order as the input items.
  PROMPT

  def initialize(openai_client: nil)
    @openai = openai_client || OpenaiClient.new
  end

  def enrich(food_menu_items)
    return [] if food_menu_items.empty?

    items_data = food_menu_items.map do |item|
      {
        name: item.name,
        price: item.price,
        category: item.category,
        ingredients: item.ingredients_array
      }
    end

    messages = [
      { role: 'system', content: 'You are a culinary expert providing menu item descriptions and standardization.' },
      { role: 'user', content: "#{ENRICHMENT_PROMPT}\n\nItems to enrich:\n#{items_data.to_json}" }
    ]

    response = @openai.chat_completion(messages, response_format: { type: 'json_object' })
    enrichments = @openai.extract_json(response)[:items]

    DB.transaction do
      food_menu_items.zip(enrichments).map do |item, enrichment|
        item.update(standardized_name: enrichment[:standardized_name])

        tags_with_labels = (enrichment[:tags] || []).map do |code|
          { code: code, label: Enums::FoodTag.label(code) || code }
        end

        EnrichedFoodMenuItem.create(
          food_menu_item_id: item.id,
          description: enrichment[:description],
          tags: Sequel.pg_jsonb(tags_with_labels)
        )

        queue_photo_synthesis(enrichment[:standardized_name])

        item.reload
      end
    end
  rescue OpenaiClient::OpenaiError => e
    raise EnrichmentError, "Food enrichment failed: #{e.message}"
  end

  def enrich_menu(food_menu)
    enrich(food_menu.food_menu_items)
  end

  private

  def queue_photo_synthesis(standardized_name)
    return if standardized_name.nil?
    return if FoodPhoto.where(standardized_name: standardized_name).any?

    Thread.new do
      FoodPhotoSynthesizer.new.synthesize(standardized_name)
    rescue StandardError => e
      warn "Photo synthesis failed for #{standardized_name}: #{e.message}"
    end
  end
end
