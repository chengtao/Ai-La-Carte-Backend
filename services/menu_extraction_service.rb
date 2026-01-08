class MenuExtractionService
  include AppLogger

  class ExtractionError < StandardError; end

  EXTRACTION_SCHEMA = {
    type: "json_schema",
    json_schema: {
      name: "menu_extraction",
      strict: true,
      schema: {
        type: "object",
        properties: {
          restaurant_name: { type: ["string", "null"] },
          restaurant_address: { type: ["string", "null"] },
          food_items: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                price: { type: ["number", "null"] },
                category: { type: "string", enum: ["appetizer", "soup", "entree", "seafood", "dessert", "other"] },
                ingredients: { type: "array", items: { type: "string" } },
                spice: { type: "integer" },
                richness: { type: "integer" }
              },
              required: ["name", "price", "category", "ingredients", "spice", "richness"],
              additionalProperties: false
            }
          },
          wine_items: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                price_glass: { type: ["number", "null"] },
                price_bottle: { type: ["number", "null"] },
                category: { type: "string", enum: ["sparkling", "white", "rose", "red", "sweet", "other"] }
              },
              required: ["name", "price_glass", "price_bottle", "category"],
              additionalProperties: false
            }
          }
        },
        required: ["restaurant_name", "restaurant_address", "food_items", "wine_items"],
        additionalProperties: false
      }
    }
  }.freeze

  EXTRACTION_PROMPT = <<~PROMPT.freeze
    Analyze these menu photos and extract all menu items. For each item, identify:

    For FOOD items:
    - name: The dish name as written on the menu
    - price: The price (number only, no currency symbol)
    - category: One of: appetizer, soup, entree, seafood, dessert, other
    - ingredients: List of main ingredients from: Beef, Pork, Chicken, Seafood, Noodle, Rice, Other
    - spice: Spiciness level 1-5 (1=mild, 5=very spicy). Use your culinary knowledge to estimate.
    - richness: Richness level 1-5 (1=light, 5=very rich). Use your culinary knowledge to estimate.

    For WINE items:
    - name: The wine name as written
    - price_glass: Price per glass if available (number only)
    - price_bottle: Price per bottle if available (number only)
    - category: One of: sparkling, white, rose, red, sweet, other

    Also extract if visible:
    - restaurant_name: Name of the restaurant if shown
    - restaurant_address: Address if shown

    Return as JSON with this exact structure:
    {
      "restaurant_name": "string or null",
      "restaurant_address": "string or null",
      "food_items": [
        {
          "name": "string",
          "price": number,
          "category": "string",
          "ingredients": ["string"],
          "spice": number,
          "richness": number
        }
      ],
      "wine_items": [
        {
          "name": "string",
          "price_glass": number or null,
          "price_bottle": number or null,
          "category": "string"
        }
      ]
    }
  PROMPT

  def initialize(openai_client: nil)
    @openai = openai_client || OpenaiClient.new
    logger.debug "MenuExtractionService initialized"
  end

  def extract(photo_urls)
    logger.info "Starting menu extraction from #{photo_urls.length} photo(s)"
    photo_urls.each_with_index { |url, i| logger.debug "  Photo #{i + 1}: #{url}" }

    if photo_urls.empty?
      logger.warn "No photos provided for extraction"
      return { food_items: [], wine_items: [] }
    end

    start_time = Time.now
    logger.info "Calling OpenAI Vision API for menu extraction..."

    response = @openai.vision_analyze(photo_urls, EXTRACTION_PROMPT, response_format: EXTRACTION_SCHEMA)

    elapsed = (Time.now - start_time).round(2)
    logger.info "OpenAI Vision API response received in #{elapsed}s"
    logger.debug "Raw response length: #{response.to_s.length} chars"

    result = @openai.extract_json(response)

    logger.info "Extraction complete:"
    logger.info "  Restaurant: #{result[:restaurant_name] || 'Not detected'}"
    logger.info "  Address: #{result[:restaurant_address] || 'Not detected'}"
    logger.info "  Food items: #{result[:food_items]&.length || 0}"
    logger.info "  Wine items: #{result[:wine_items]&.length || 0}"

    if result[:food_items]&.any?
      logger.debug "Food items extracted:"
      result[:food_items].each_with_index do |item, i|
        logger.debug "  #{i + 1}. #{item[:name]} ($#{item[:price]}) [#{item[:category]}]"
      end
    end

    if result[:wine_items]&.any?
      logger.debug "Wine items extracted:"
      result[:wine_items].each_with_index do |item, i|
        logger.debug "  #{i + 1}. #{item[:name]} (glass: $#{item[:price_glass]}, bottle: $#{item[:price_bottle]}) [#{item[:category]}]"
      end
    end

    result
  rescue OpenaiClient::OpenaiError => e
    logger.error "Menu extraction failed: #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise ExtractionError, "Menu extraction failed: #{e.message}"
  end
end
