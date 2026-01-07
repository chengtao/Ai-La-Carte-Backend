class WineMenuEnrichmentService
  class EnrichmentError < StandardError; end

  ENRICHMENT_PROMPT = <<~PROMPT.freeze
    For each wine item, provide enrichment data based on your wine knowledge:

    - grape_varietal: The grape variety (e.g., "Cabernet Sauvignon", "Chardonnay", "Pinot Noir")
    - country: Country of origin (e.g., "France", "USA", "Italy")
    - region: Wine region (e.g., "Napa Valley", "Bordeaux", "Tuscany")
    - description: A 1-2 sentence description of the wine's character and tasting notes
    - flavor: One of: Elegant, Fruity, Full-Body, Sweet, Acidic

    Use your wine knowledge to infer details from the wine name. If you cannot determine
    a value with confidence, use reasonable defaults based on the wine category.

    Return JSON with this exact structure:
    {
      "wines": [
        {
          "grape_varietal": "string",
          "country": "string",
          "region": "string",
          "description": "string",
          "flavor": "string"
        }
      ]
    }

    The wines array MUST be in the same order as the input wines.
  PROMPT

  def initialize(openai_client: nil)
    @openai = openai_client || OpenaiClient.new
  end

  def enrich(wine_menu_items)
    return [] if wine_menu_items.empty?

    items_data = wine_menu_items.map do |item|
      {
        name: item.name,
        category: item.category,
        price_glass: item.price_glass,
        price_bottle: item.price_bottle
      }
    end

    messages = [
      { role: 'system', content: 'You are a sommelier providing wine information and recommendations.' },
      { role: 'user', content: "#{ENRICHMENT_PROMPT}\n\nWines to enrich:\n#{items_data.to_json}" }
    ]

    response = @openai.chat_completion(messages, response_format: { type: 'json_object' })
    enrichments = @openai.extract_json(response)[:wines]

    DB.transaction do
      wine_menu_items.zip(enrichments).map do |item, enrichment|
        EnrichedWineMenuItem.create(
          wine_menu_item_id: item.id,
          grape_varietal: enrichment[:grape_varietal],
          description: enrichment[:description],
          country: enrichment[:country],
          region: enrichment[:region],
          flavor: enrichment[:flavor]
        )

        item.reload
      end
    end
  rescue OpenaiClient::OpenaiError => e
    raise EnrichmentError, "Wine enrichment failed: #{e.message}"
  end

  def enrich_menu(wine_menu)
    enrich(wine_menu.wine_menu_items)
  end
end
