# frozen_string_literal: true

class ApiController < BaseController
  before '/api/*' do
    content_type :json
    headers 'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization'

    logger.info "API Request: #{request.request_method} #{request.path_info}"
    logger.debug "Query: #{request.query_string}" unless request.query_string.empty?
  end

  after '/api/*' do
    logger.info "API Response: #{response.status}"
  end

  options '/api/*' do
    200
  end

  # Get session by ID (supports UUID or integer ID)
  # GET /api/sessions/:id
  get '/api/sessions/:id' do
    session_record = Session.find_by_uuid(params[:id]) || Session[params[:id]]
    not_found_error('Session') unless session_record

    json_response(session_record.to_api_hash)
  end

  # Get presigned URL for photo upload
  # POST /api/presigned_upload
  # Body: { filename: string, content_type: string }
  post '/api/presigned_upload' do
    filename = json_params[:filename]
    content_type_param = json_params[:content_type] || 'image/jpeg'

    json_error('filename is required', status: 400) unless filename

    s3 = S3Client.new
    key = "uploads/#{Time.now.to_i}_#{SecureRandom.hex(8)}_#{filename}"
    upload_url = s3.presigned_upload_url(key, content_type: content_type_param)
    public_url = s3.public_url(key)

    json_response({
      upload_url: upload_url,
      public_url: public_url,
      key: key
    })
  end

  # Search restaurants
  # GET /api/restaurants
  # Params: lat, lng, radius (km), q (search query)
  get '/api/restaurants' do
    restaurants = Restaurant.dataset

    if params[:q] && !params[:q].empty?
      restaurants = restaurants.search(params[:q])
    elsif params[:lat] && params[:lng]
      lat = params[:lat].to_f
      lng = params[:lng].to_f
      radius = (params[:radius] || 5).to_f
      restaurants = restaurants.near(lat, lng, radius)
    end

    restaurants = restaurants.limit(Constants::Pagination::API_DEFAULT_LIMIT)

    json_response({
      restaurants: restaurants.all.map(&:to_api_hash)
    })
  end

  # Nearby restaurants search - must be before :id route
  # GET /api/restaurants/nearby
  get '/api/restaurants/nearby' do
    lat = params[:lat]&.to_f
    lon = params[:lon]&.to_f || params[:lng]&.to_f
    radius_m = (params[:radius_m] || 5000).to_f
    radius_km = radius_m / 1000.0

    json_error('lat and lon/lng are required', status: 400) unless lat && lon

    restaurants = Restaurant.near(lat, lon, radius_km)
                            .limit(Constants::Pagination::API_DEFAULT_LIMIT)
                            .all

    json_response({
      restaurants: restaurants.map(&:to_api_hash)
    })
  end

  # Get restaurant by ID
  # GET /api/restaurants/:id
  get '/api/restaurants/:id' do
    restaurant = Restaurant[params[:id]]
    not_found_error('Restaurant') unless restaurant

    json_response(restaurant.to_api_hash_with_menus)
  end

  # Get food menu by ID
  # GET /api/food_menus/:id
  get '/api/food_menus/:id' do
    menu = FoodMenu[params[:id]]
    not_found_error('Food menu') unless menu

    json_response(menu.to_api_hash)
  end

  # Get wine menu by ID
  # GET /api/wine_menus/:id
  get '/api/wine_menus/:id' do
    menu = WineMenu[params[:id]]
    not_found_error('Wine menu') unless menu

    json_response(menu.to_api_hash)
  end

  # Get food photo by standardized name
  # GET /api/food_photos/:standardized_name
  get '/api/food_photos/:standardized_name' do
    photo = FoodPhoto.where(standardized_name: params[:standardized_name]).first
    not_found_error('Food photo') unless photo

    json_response(photo.to_api_hash)
  end

  # ============================================
  # iOS API CONTRACT ENDPOINTS
  # ============================================

  # Upload photo to session (creates session if needed)
  # POST /api/sessions/:session_id/photos
  # Multipart form-data with field "file"
  # Returns: { photo_id: string, url: string }
  post '/api/sessions/:session_id/photos' do
    session_uuid = params[:session_id]

    # Validate UUID format
    json_error('Invalid session ID format', status: 400) unless valid_uuid?(session_uuid)

    # Get or create session
    session_record = Session.find_or_create_by_uuid(session_uuid)

    # Handle file upload
    file = params[:file]
    json_error('file is required', status: 400) unless file && file[:tempfile]

    # Upload to S3
    s3 = S3Client.new
    filename = file[:filename] || "photo_#{Time.now.to_i}.jpg"
    content_type_value = file[:type] || 'image/jpeg'
    key = "static/sessions/#{session_uuid}/#{Time.now.to_i}_#{SecureRandom.hex(4)}_#{filename}"

    url = s3.upload(key, file[:tempfile], content_type: content_type_value)

    # Create photo record
    photo = SessionPhoto.create(
      session_id: session_record.id,
      url: url,
      s3_key: key,
      content_type: content_type_value,
      file_size: file[:tempfile].size
    )

    json_response(photo.to_api_hash, status: 201)
  end

  # Trigger menu creation from session photos
  # POST /api/sessions/:session_id/menus/create?lat={lat}&lon={lon}
  # Returns: { job_id: string, status: string }
  post '/api/sessions/:session_id/menus/create' do
    session_uuid = params[:session_id]
    session_record = Session.find_by_uuid(session_uuid)
    not_found_error('Session') unless session_record

    # Update session location if provided
    lat = params[:lat]&.to_f
    lon = params[:lon]&.to_f || params[:lng]&.to_f
    session_record.update(lat: lat, lng: lon) if lat && lon

    # Check if session has photos
    json_error('No photos uploaded to session', status: 400) if session_record.photo_urls_array.empty?

    # Create job
    job = Job.create(
      session_id: session_record.id,
      lat: lat,
      lng: lon,
      status: 'created'
    )

    # Run async
    JobRunner.run_async(job, logger: logger)

    json_response(job.to_api_hash, status: 202)
  end

  # Get job status
  # GET /api/menus/status?job_id={jobId}
  # Returns: { job_id: string, status: string, progress: float }
  get '/api/menus/status' do
    job_id = params[:job_id]
    json_error('job_id is required', status: 400) unless job_id

    job = Job.where(uuid: job_id).first
    not_found_error('Job') unless job

    response_data = job.to_api_hash

    # Include menu IDs when done
    if job.status == 'done'
      response_data[:food_menu_id] = job.food_menu_id
      response_data[:wine_menu_id] = job.wine_menu_id
    end

    # Include error when failed
    response_data[:error] = job.error_message if job.status == 'failed'

    json_response(response_data)
  end

  # Get menus by ID
  # GET /api/menus?food_id={foodId}&wine_id={wineId}
  # Returns: { food: [FoodItem], wine: [WineItem] }
  get '/api/menus' do
    food_id = params[:food_id]
    wine_id = params[:wine_id]

    json_error('food_id or wine_id is required', status: 400) unless food_id || wine_id

    response_data = { food: [], wine: [] }

    if food_id
      food_menu = FoodMenu[food_id]
      response_data[:food] = food_menu ? food_menu.food_menu_items.map(&:to_api_hash) : []
    end

    if wine_id
      wine_menu = WineMenu[wine_id]
      response_data[:wine] = wine_menu ? wine_menu.wine_menu_items.map(&:to_api_hash) : []
    end

    json_response(response_data)
  end

  # Submit feedback
  # POST /api/sessions/:session_id/feedback
  # Body: { item_id: string, action: "loved"|"disliked"|"not_ordered" }
  post '/api/sessions/:session_id/feedback' do
    session_uuid = params[:session_id]
    session_record = Session.find_by_uuid(session_uuid)
    not_found_error('Session') unless session_record

    item_id = json_params[:item_id]
    action = json_params[:action]

    json_error('item_id is required', status: 400) unless item_id
    json_error('action is required', status: 400) unless action
    json_error('action must be loved, disliked, or not_ordered', status: 400) unless Feedback::ACTIONS.include?(action)

    # Determine item type (food or wine)
    item_type = determine_item_type(item_id)
    json_error('Invalid item_id', status: 400) unless item_type

    feedback = Feedback.create(
      session_id: session_record.id,
      item_id: item_id.to_s,
      item_type: item_type,
      action: action
    )

    json_response(feedback.to_api_hash, status: 201)
  end

  # Record analytics event
  # POST /api/events
  # Body: { session_id, user_id, device_id, event, meta }
  post '/api/events' do
    event_name = json_params[:event]
    json_error('event is required', status: 400) unless event_name

    event = Event.create(
      session_id: json_params[:session_id],
      user_id: json_params[:user_id],
      device_id: json_params[:device_id],
      event: event_name,
      meta: Sequel.pg_jsonb(json_params[:meta] || {})
    )

    json_response({ id: event.id }, status: 201)
  end

  private

  def valid_uuid?(str)
    str.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end

  def determine_item_type(item_id)
    return 'food' if FoodMenuItem[item_id]
    return 'wine' if WineMenuItem[item_id]

    nil
  end

  def enrich_menus_async(food_menu, wine_menu)
    Thread.new do
      FoodMenuEnrichmentService.new.enrich_menu(food_menu) if food_menu
    rescue StandardError => e
      logger.error "Food menu enrichment failed: #{e.message}"
    end

    Thread.new do
      WineMenuEnrichmentService.new.enrich_menu(wine_menu) if wine_menu
    rescue StandardError => e
      logger.error "Wine menu enrichment failed: #{e.message}"
    end
  end
end
