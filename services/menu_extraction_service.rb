class MenuExtractionService
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
  end

  def extract(photo_urls)
    return { food_items: [], wine_items: [] } if photo_urls.empty?

    response = @openai.vision_analyze(photo_urls, EXTRACTION_PROMPT, response_format: EXTRACTION_SCHEMA)
    @openai.extract_json(response)
  rescue OpenaiClient::OpenaiError => e
    raise ExtractionError, "Menu extraction failed: #{e.message}"
  end

end
