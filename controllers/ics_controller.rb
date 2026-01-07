class IcsController < BaseController
  ICS_USERNAME = 'office'.freeze
  ICS_PASSWORD = 'OfficeManager!123'.freeze

  before '/ics/*' do
    content_type :html
    pass if request.path_info == '/ics/home' || request.path_info == '/ics/login'
    redirect '/ics/home' unless authenticated?
  end

  # Login page
  get '/ics/home' do
    redirect '/ics/sessions' if authenticated?
    haml :'ics/home', layout: :layout
  end

  # Handle login
  post '/ics/login' do
    if params[:username] == ICS_USERNAME && params[:password] == ICS_PASSWORD
      session[:user] = { username: params[:username] }
      redirect '/ics/sessions'
    else
      @error = 'Invalid username or password'
      haml :'ics/home', layout: :layout
    end
  end

  # Logout
  get '/ics/logout' do
    session.clear
    redirect '/ics/home'
  end

  # Sessions list (reviewed and unreviewed)
  get '/ics/sessions' do
    @unreviewed_sessions = Session.unreviewed.order(Sequel.desc(:created_at)).limit(50).all
    @reviewed_sessions = Session.reviewed.order(Sequel.desc(:created_at)).limit(50).all
    haml :'ics/sessions', layout: :layout
  end

  # Session detail
  get '/ics/sessions/:id' do
    @session = Session[params[:id]]
    halt 404, 'Session not found' unless @session

    @restaurants = Restaurant.order(:name).limit(100).all
    haml :'ics/session_detail', layout: :layout
  end

  # Review session - associate with restaurant
  post '/ics/sessions/:id/review' do
    @session = Session[params[:id]]
    halt 404, 'Session not found' unless @session

    restaurant_id = params[:restaurant_id]

    if restaurant_id && !restaurant_id.empty?
      restaurant = Restaurant[restaurant_id]

      if restaurant && params[:food_menu_id]
        restaurant.update(food_menu_id: params[:food_menu_id])
      end

      if restaurant && params[:wine_menu_id]
        restaurant.update(wine_menu_id: params[:wine_menu_id])
      end
    end

    Review.create(
      session_id: @session.id,
      reviewed_at: Time.now
    ) unless @session.reviewed?

    redirect '/ics/sessions'
  end

  # Update menu item
  post '/ics/sessions/:session_id/food_items/:item_id' do
    item = FoodMenuItem[params[:item_id]]
    halt 404, 'Item not found' unless item

    item.update(
      name: params[:name],
      standardized_name: params[:standardized_name],
      price: params[:price].to_f,
      category: params[:category],
      spice: params[:spice].to_i,
      richness: params[:richness].to_i
    )

    redirect "/ics/sessions/#{params[:session_id]}"
  end

  # Restaurants list
  get '/ics/restaurants' do
    @restaurants = if params[:q] && !params[:q].empty?
                     Restaurant.search(params[:q]).order(:name).limit(100).all
                   else
                     Restaurant.order(Sequel.desc(:created_at)).limit(100).all
                   end
    haml :'ics/restaurants', layout: :layout
  end

  # Create restaurant
  post '/ics/restaurants' do
    Restaurant.create(
      name: params[:name],
      address: params[:address],
      cuisine: params[:cuisine],
      lat: params[:lat]&.to_f,
      lng: params[:lng]&.to_f
    )
    redirect '/ics/restaurants'
  end

  # Restaurant detail
  get '/ics/restaurants/:id' do
    @restaurant = Restaurant[params[:id]]
    halt 404, 'Restaurant not found' unless @restaurant
    haml :'ics/restaurant_detail', layout: :layout
  end

  # Update restaurant
  post '/ics/restaurants/:id' do
    restaurant = Restaurant[params[:id]]
    halt 404, 'Restaurant not found' unless restaurant

    restaurant.update(
      name: params[:name],
      address: params[:address],
      cuisine: params[:cuisine],
      lat: params[:lat]&.to_f,
      lng: params[:lng]&.to_f
    )
    redirect '/ics/restaurants'
  end

  # Delete restaurant
  post '/ics/restaurants/:id/delete' do
    restaurant = Restaurant[params[:id]]
    restaurant&.destroy
    redirect '/ics/restaurants'
  end

  # Synthesized photos list
  get '/ics/synthesized_photos' do
    @photos = if params[:q] && !params[:q].empty?
                FoodPhoto.search(params[:q]).order(Sequel.desc(:id)).limit(100).all
              else
                FoodPhoto.order(Sequel.desc(:id)).limit(100).all
              end
    haml :'ics/synthesized_photos', layout: :layout
  end

  # Regenerate photo
  post '/ics/synthesized_photos/:id/regenerate' do
    photo = FoodPhoto[params[:id]]
    halt 404, 'Photo not found' unless photo

    begin
      FoodPhotoSynthesizer.new.regenerate(photo.standardized_name)
      redirect '/ics/synthesized_photos'
    rescue FoodPhotoSynthesizer::SynthesisError => e
      @error = e.message
      @photos = FoodPhoto.order(Sequel.desc(:id)).limit(100).all
      haml :'ics/synthesized_photos', layout: :layout
    end
  end
end
