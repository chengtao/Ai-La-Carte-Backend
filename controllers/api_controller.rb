class ApiController < BaseController
  before '/api/*' do
    content_type :json
    headers 'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
  end

  options '/api/*' do
    200
  end

  # Create a new session with menu photos
  # POST /api/sessions
  # Body: { photo_urls: [], lat: float, lng: float, potential_restaurant_name: string, potential_address: string }
  post '/api/sessions' do
    photo_urls = json_params[:photo_urls] || []
    json_error('photo_urls is required and must be an array', status: 400) unless photo_urls.is_a?(Array)

    extraction_service = MenuExtractionService.new
    result = extraction_service.create_session_with_extraction(
      photo_urls: photo_urls,
      lat: json_params[:lat],
      lng: json_params[:lng],
      potential_restaurant_name: json_params[:potential_restaurant_name],
      potential_address: json_params[:potential_address]
    )

    # Trigger enrichment asynchronously
    enrich_menus_async(result[:food_menu], result[:wine_menu])

    json_response({
      session: result[:session].to_api_hash,
      food_menu: result[:food_menu]&.to_api_hash,
      wine_menu: result[:wine_menu]&.to_api_hash,
      extraction: result[:extraction]
    }, status: 201)
  rescue MenuExtractionService::ExtractionError => e
    json_error(e.message, status: 503)
  end

  # Get session by ID
  # GET /api/sessions/:id
  get '/api/sessions/:id' do
    session = Session[params[:id]]
    not_found_error('Session') unless session

    json_response(session.to_api_hash)
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

    restaurants = restaurants.limit(50)

    json_response({
      restaurants: restaurants.all.map(&:to_api_hash)
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

  private

  def enrich_menus_async(food_menu, wine_menu)
    Thread.new do
      FoodMenuEnrichmentService.new.enrich_menu(food_menu) if food_menu
    rescue StandardError => e
      warn "Food menu enrichment failed: #{e.message}"
    end

    Thread.new do
      WineMenuEnrichmentService.new.enrich_menu(wine_menu) if wine_menu
    rescue StandardError => e
      warn "Wine menu enrichment failed: #{e.message}"
    end
  end
end
