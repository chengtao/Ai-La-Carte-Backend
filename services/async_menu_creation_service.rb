# frozen_string_literal: true

class AsyncMenuCreationService
  include AppLogger

  class CreationError < StandardError; end

  def initialize(job:, extraction_service: nil, food_enrichment_service: nil, wine_enrichment_service: nil)
    @job = job
    @extraction_service = extraction_service || MenuExtractionService.new
    @food_enrichment_service = food_enrichment_service || FoodMenuEnrichmentService.new
    @wine_enrichment_service = wine_enrichment_service || WineMenuEnrichmentService.new
    logger.debug "AsyncMenuCreationService initialized for job #{@job.uuid}"
  end

  def execute
    start_time = Time.now
    session = @job.session
    photo_urls = session.photo_urls_array

    logger.info "=" * 60
    logger.info "Starting menu creation for job #{@job.uuid}"
    logger.info "Session ID: #{session.id}"
    logger.info "Photos: #{photo_urls.length}"
    logger.info "=" * 60

    if photo_urls.empty?
      logger.error "No photos uploaded for session #{session.id}"
      return fail_job('No photos uploaded')
    end

    photo_urls.each_with_index { |url, i| logger.debug "Photo #{i + 1}: #{url}" }

    # Step 1: Parse menu from photos
    logger.info "[Step 1/4] Parsing menu from photos..."
    @job.update_status('parsing_menu', progress: 0.2)

    extraction_start = Time.now
    extraction = @extraction_service.extract(photo_urls)
    extraction_elapsed = (Time.now - extraction_start).round(2)

    logger.info "Extraction completed in #{extraction_elapsed}s"
    logger.info "  Restaurant: #{extraction[:restaurant_name] || 'Unknown'}"
    logger.info "  Address: #{extraction[:restaurant_address] || 'Unknown'}"
    logger.info "  Food items: #{extraction[:food_items]&.length || 0}"
    logger.info "  Wine items: #{extraction[:wine_items]&.length || 0}"

    # Step 2: Create menu records
    logger.info "[Step 2/4] Creating menu records..."
    @job.update_status('building_profile', progress: 0.4)

    food_menu = nil
    wine_menu = nil

    DB.transaction do
      logger.debug "Starting database transaction for menu creation"

      if extraction[:food_items]&.any?
        food_menu = create_food_menu(extraction[:food_items])
        logger.info "Created food menu (id: #{food_menu.id}) with #{extraction[:food_items].length} items"
      else
        logger.info "No food items to create"
      end

      if extraction[:wine_items]&.any?
        wine_menu = create_wine_menu(extraction[:wine_items])
        logger.info "Created wine menu (id: #{wine_menu.id}) with #{extraction[:wine_items].length} items"
      else
        logger.info "No wine items to create"
      end

      # Update session with extracted info and menu references
      session.update(
        potential_restaurant_name: extraction[:restaurant_name] || session.potential_restaurant_name,
        potential_address: extraction[:restaurant_address] || session.potential_address,
        food_menu_id: food_menu&.id,
        wine_menu_id: wine_menu&.id
      )
      logger.debug "Updated session #{session.id} with menu references"

      @job.update(food_menu_id: food_menu&.id, wine_menu_id: wine_menu&.id)
      logger.debug "Updated job #{@job.uuid} with menu references"
    end

    # Step 3: Enrich menus (can run in parallel)
    logger.info "[Step 3/4] Enriching menus..."
    @job.update_status('collecting_reviews', progress: 0.6)

    enrichment_start = Time.now
    threads = []

    if food_menu
      logger.info "Starting food menu enrichment in background thread"
      threads << Thread.new do
        Thread.current[:name] = "food_enrichment"
        @food_enrichment_service.enrich_menu(food_menu)
      end
    end

    if wine_menu
      logger.info "Starting wine menu enrichment in background thread"
      threads << Thread.new do
        Thread.current[:name] = "wine_enrichment"
        @wine_enrichment_service.enrich_menu(wine_menu)
      end
    end

    logger.info "Waiting for #{threads.length} enrichment thread(s) to complete..."
    threads.each(&:join)
    enrichment_elapsed = (Time.now - enrichment_start).round(2)
    logger.info "All enrichment threads completed in #{enrichment_elapsed}s"

    # Step 4: Ranking (placeholder for future ranking logic)
    logger.info "[Step 4/4] Ranking items..."
    @job.update_status('ranking', progress: 0.9)
    logger.debug "Ranking step placeholder - no ranking logic implemented yet"

    # Complete
    @job.update_status('done', progress: 1.0)

    total_elapsed = (Time.now - start_time).round(2)
    logger.info "=" * 60
    logger.info "Menu creation completed for job #{@job.uuid}"
    logger.info "Total time: #{total_elapsed}s"
    logger.info "Food menu ID: #{food_menu&.id || 'N/A'}"
    logger.info "Wine menu ID: #{wine_menu&.id || 'N/A'}"
    logger.info "=" * 60

    { food_menu: food_menu, wine_menu: wine_menu, extraction: extraction }
  rescue StandardError => e
    total_elapsed = (Time.now - start_time).round(2) rescue 0
    logger.error "=" * 60
    logger.error "Menu creation FAILED for job #{@job.uuid}"
    logger.error "Error: #{e.class} - #{e.message}"
    logger.error "Time elapsed: #{total_elapsed}s"
    logger.error "Backtrace:"
    e.backtrace&.first(10)&.each { |line| logger.error "  #{line}" }
    logger.error "=" * 60

    fail_job(e.message)
    raise CreationError, e.message
  end

  private

  def fail_job(message)
    logger.warn "Marking job #{@job.uuid} as failed: #{message}"
    @job.update(status: 'failed', error_message: message, completed_at: Time.now)
  end

  def create_food_menu(items)
    return nil if items.nil? || items.empty?

    logger.debug "Creating food menu with #{items.length} items"
    food_menu = FoodMenu.create
    logger.debug "Created FoodMenu (id: #{food_menu.id})"

    items.each_with_index do |item, index|
      food_item = FoodMenuItem.create(
        menu_id: food_menu.id,
        name: item[:name],
        price: item[:price],
        category: item[:category] || 'other',
        spice: item[:spice],
        richness: item[:richness],
        ingredients: Sequel.pg_jsonb(item[:ingredients] || [])
      )
      logger.debug "  #{index + 1}. Created FoodMenuItem (id: #{food_item.id}): #{item[:name]}"
    end

    food_menu
  end

  def create_wine_menu(items)
    return nil if items.nil? || items.empty?

    logger.debug "Creating wine menu with #{items.length} items"
    wine_menu = WineMenu.create
    logger.debug "Created WineMenu (id: #{wine_menu.id})"

    items.each_with_index do |item, index|
      wine_item = WineMenuItem.create(
        menu_id: wine_menu.id,
        name: item[:name],
        price_glass: item[:price_glass],
        price_bottle: item[:price_bottle],
        category: item[:category] || 'other'
      )
      logger.debug "  #{index + 1}. Created WineMenuItem (id: #{wine_item.id}): #{item[:name]}"
    end

    wine_menu
  end
end
