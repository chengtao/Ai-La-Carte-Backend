class FoodMenuEnrichmentService
  include AppLogger

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
    logger.debug "FoodMenuEnrichmentService initialized"
  end

  def enrich(food_menu_items)
    logger.info "Starting food menu enrichment for #{food_menu_items.length} item(s)"

    if food_menu_items.empty?
      logger.warn "No food items provided for enrichment"
      return []
    end

    items_data = food_menu_items.map do |item|
      {
        name: item.name,
        price: item.price,
        category: item.category,
        ingredients: item.ingredients_array
      }
    end

    logger.debug "Food items to enrich:"
    items_data.each_with_index do |item, i|
      logger.debug "  #{i + 1}. #{item[:name]} ($#{item[:price]}) [#{item[:category]}]"
    end

    messages = [
      { role: 'system', content: 'You are a culinary expert providing menu item descriptions and standardization.' },
      { role: 'user', content: "#{ENRICHMENT_PROMPT}\n\nItems to enrich:\n#{items_data.to_json}" }
    ]

    start_time = Time.now
    logger.info "Calling OpenAI Chat API for food enrichment..."

    response = @openai.chat_completion(messages, response_format: { type: 'json_object' })

    elapsed = (Time.now - start_time).round(2)
    logger.info "OpenAI Chat API response received in #{elapsed}s"

    enrichments = @openai.extract_json(response)[:items]
    logger.info "Received #{enrichments&.length || 0} enrichment(s) from OpenAI"

    logger.debug "Starting database transaction for enrichment records..."
    photos_to_synthesize = []

    DB.transaction do
      food_menu_items.zip(enrichments).map do |item, enrichment|
        logger.debug "Enriching item #{item.id}: #{item.name}"
        logger.debug "  Standardized: #{enrichment[:standardized_name]}"
        logger.debug "  Tags: #{enrichment[:tags]&.join(', ') || 'none'}"

        item.update(standardized_name: enrichment[:standardized_name])

        tags_with_labels = (enrichment[:tags] || []).map do |code|
          { code: code, label: Enums::FoodTag.label(code) || code }
        end

        EnrichedFoodMenuItem.create(
          food_menu_item_id: item.id,
          description: enrichment[:description],
          tags: Sequel.pg_jsonb(tags_with_labels)
        )

        logger.debug "  Created EnrichedFoodMenuItem for item #{item.id}"

        # Collect photos to synthesize (will batch process after transaction)
        photos_to_synthesize << enrichment[:standardized_name] if enrichment[:standardized_name]

        item.reload
      end
    end

    # Queue photo synthesis in a single background thread (batched)
    queue_batch_photo_synthesis(photos_to_synthesize)

    logger.info "Food menu enrichment completed successfully"
    food_menu_items
  rescue OpenaiClient::OpenaiError => e
    logger.error "Food enrichment failed: #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise EnrichmentError, "Food enrichment failed: #{e.message}"
  rescue StandardError => e
    logger.error "Unexpected error during food enrichment: #{e.class} - #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise
  end

  def enrich_menu(food_menu)
    logger.info "Enriching food menu #{food_menu.id}"
    enrich(food_menu.food_menu_items)
  end

  private

  # Process all photo synthesis in a single background thread to avoid connection pool exhaustion
  def queue_batch_photo_synthesis(standardized_names)
    return if standardized_names.empty?

    # Filter out photos that already exist
    names_to_process = standardized_names.uniq.reject do |name|
      FoodPhoto.where(standardized_name: name).any?
    end

    if names_to_process.empty?
      logger.debug "All photos already exist, skipping synthesis"
      return
    end

    logger.info "Queuing batch photo synthesis for #{names_to_process.length} item(s)"

    # Single thread processes all photos sequentially
    Thread.new do
      synthesizer = FoodPhotoSynthesizer.new
      names_to_process.each_with_index do |name, index|
        logger.info "Photo synthesis #{index + 1}/#{names_to_process.length}: '#{name}'"
        begin
          synthesizer.synthesize(name)
          logger.info "Photo synthesis completed for '#{name}'"
        rescue StandardError => e
          logger.error "Photo synthesis failed for '#{name}': #{e.message}"
        end
      end
      logger.info "Batch photo synthesis completed (#{names_to_process.length} items)"
    rescue StandardError => e
      logger.error "Batch photo synthesis thread failed: #{e.message}"
    end
  end
end
