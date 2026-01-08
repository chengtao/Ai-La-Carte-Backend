class WineMenuEnrichmentService
  include AppLogger

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
    logger.debug "WineMenuEnrichmentService initialized"
  end

  def enrich(wine_menu_items)
    logger.info "Starting wine menu enrichment for #{wine_menu_items.length} item(s)"

    if wine_menu_items.empty?
      logger.warn "No wine items provided for enrichment"
      return []
    end

    items_data = wine_menu_items.map do |item|
      {
        name: item.name,
        category: item.category,
        price_glass: item.price_glass,
        price_bottle: item.price_bottle
      }
    end

    logger.debug "Wine items to enrich:"
    items_data.each_with_index do |item, i|
      logger.debug "  #{i + 1}. #{item[:name]} (glass: $#{item[:price_glass]}, bottle: $#{item[:price_bottle]}) [#{item[:category]}]"
    end

    messages = [
      { role: 'system', content: 'You are a sommelier providing wine information and recommendations.' },
      { role: 'user', content: "#{ENRICHMENT_PROMPT}\n\nWines to enrich:\n#{items_data.to_json}" }
    ]

    start_time = Time.now
    logger.info "Calling OpenAI Chat API for wine enrichment..."

    response = @openai.chat_completion(messages, response_format: { type: 'json_object' })

    elapsed = (Time.now - start_time).round(2)
    logger.info "OpenAI Chat API response received in #{elapsed}s"

    enrichments = @openai.extract_json(response)[:wines]
    logger.info "Received #{enrichments&.length || 0} enrichment(s) from OpenAI"

    logger.debug "Starting database transaction for wine enrichment records..."
    DB.transaction do
      wine_menu_items.zip(enrichments).map do |item, enrichment|
        logger.debug "Enriching wine item #{item.id}: #{item.name}"
        logger.debug "  Grape: #{enrichment[:grape_varietal]}"
        logger.debug "  Origin: #{enrichment[:country]}, #{enrichment[:region]}"
        logger.debug "  Flavor: #{enrichment[:flavor]}"

        EnrichedWineMenuItem.create(
          wine_menu_item_id: item.id,
          grape_varietal: enrichment[:grape_varietal],
          description: enrichment[:description],
          country: enrichment[:country],
          region: enrichment[:region],
          flavor: enrichment[:flavor]
        )

        logger.debug "  Created EnrichedWineMenuItem for item #{item.id}"

        item.reload
      end
    end

    logger.info "Wine menu enrichment completed successfully"
    wine_menu_items
  rescue OpenaiClient::OpenaiError => e
    logger.error "Wine enrichment failed: #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise EnrichmentError, "Wine enrichment failed: #{e.message}"
  rescue StandardError => e
    logger.error "Unexpected error during wine enrichment: #{e.class} - #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise
  end

  def enrich_menu(wine_menu)
    logger.info "Enriching wine menu #{wine_menu.id}"
    enrich(wine_menu.wine_menu_items)
  end
end
