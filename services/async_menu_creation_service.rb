# frozen_string_literal: true

class AsyncMenuCreationService
  class CreationError < StandardError; end

  def initialize(job:, extraction_service: nil, food_enrichment_service: nil, wine_enrichment_service: nil, logger: nil)
    @job = job
    @extraction_service = extraction_service || MenuExtractionService.new
    @food_enrichment_service = food_enrichment_service || FoodMenuEnrichmentService.new
    @wine_enrichment_service = wine_enrichment_service || WineMenuEnrichmentService.new
    @logger = logger || Logger.new($stdout)
  end

  def execute
    session = @job.session
    photo_urls = session.photo_urls_array

    return fail_job('No photos uploaded') if photo_urls.empty?

    @logger.info "Starting menu creation for job #{@job.uuid} with #{photo_urls.length} photos"

    # Step 1: Parse menu from photos
    @job.update_status('parsing_menu', progress: 0.2)
    extraction = @extraction_service.extract(photo_urls)

    # Step 2: Create menu records
    @job.update_status('building_profile', progress: 0.4)
    food_menu = nil
    wine_menu = nil

    DB.transaction do
      food_menu = create_food_menu(extraction[:food_items]) if extraction[:food_items]&.any?
      wine_menu = create_wine_menu(extraction[:wine_items]) if extraction[:wine_items]&.any?

      # Update session with extracted info and menu references
      session.update(
        potential_restaurant_name: extraction[:restaurant_name] || session.potential_restaurant_name,
        potential_address: extraction[:restaurant_address] || session.potential_address,
        food_menu_id: food_menu&.id,
        wine_menu_id: wine_menu&.id
      )

      @job.update(food_menu_id: food_menu&.id, wine_menu_id: wine_menu&.id)
    end

    # Step 3: Enrich menus (can run in parallel)
    @job.update_status('collecting_reviews', progress: 0.6)

    threads = []
    threads << Thread.new { @food_enrichment_service.enrich_menu(food_menu) } if food_menu
    threads << Thread.new { @wine_enrichment_service.enrich_menu(wine_menu) } if wine_menu
    threads.each(&:join)

    # Step 4: Ranking (placeholder for future ranking logic)
    @job.update_status('ranking', progress: 0.9)

    # Complete
    @job.update_status('done', progress: 1.0)
    @logger.info "Menu creation completed for job #{@job.uuid}"

    { food_menu: food_menu, wine_menu: wine_menu, extraction: extraction }
  rescue StandardError => e
    @logger.error "Menu creation failed for job #{@job.uuid}: #{e.message}"
    fail_job(e.message)
    raise CreationError, e.message
  end

  private

  def fail_job(message)
    @job.update(status: 'failed', error_message: message, completed_at: Time.now)
  end

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
