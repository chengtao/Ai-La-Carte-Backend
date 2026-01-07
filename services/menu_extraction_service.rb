class MenuExtractionService
  class ExtractionError < StandardError; end

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

    response = @openai.vision_analyze(photo_urls, EXTRACTION_PROMPT)
    @openai.extract_json(response)
  rescue OpenaiClient::OpenaiError => e
    raise ExtractionError, "Menu extraction failed: #{e.message}"
  end

  def create_session_with_extraction(photo_urls:, lat:, lng:, potential_restaurant_name: nil, potential_address: nil)
    extraction = extract(photo_urls)

    DB.transaction do
      session = Session.create(
        photo_urls: Sequel.pg_jsonb(photo_urls),
        lat: lat,
        lng: lng,
        potential_restaurant_name: extraction[:restaurant_name] || potential_restaurant_name,
        potential_address: extraction[:restaurant_address] || potential_address
      )

      food_menu = create_food_menu(extraction[:food_items]) if extraction[:food_items]&.any?
      wine_menu = create_wine_menu(extraction[:wine_items]) if extraction[:wine_items]&.any?

      {
        session: session,
        food_menu: food_menu,
        wine_menu: wine_menu,
        extraction: extraction
      }
    end
  end

  private

  def create_food_menu(items)
    return nil if items.nil? || items.empty?

    food_menu = FoodMenu.create

    items.each do |item|
      FoodMenuItem.create(
        menu_id: food_menu.id,
        name: item[:name],
        price: item[:price],
        category: item[:category] || 'other',
        spice: item[:spice],
        richness: item[:richness],
        ingredients: Sequel.pg_jsonb(item[:ingredients] || [])
      )
    end

    food_menu
  end

  def create_wine_menu(items)
    return nil if items.nil? || items.empty?

    wine_menu = WineMenu.create

    items.each do |item|
      WineMenuItem.create(
        menu_id: wine_menu.id,
        name: item[:name],
        price_glass: item[:price_glass],
        price_bottle: item[:price_bottle],
        category: item[:category] || 'other'
      )
    end

    wine_menu
  end
end
