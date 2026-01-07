This folder is for the backend implementation of "~/Development/Ai La Carte" in ruby, sinatra, haml, postgres and the server will be deployed to Heroku and postgres add-on. Please set up the structure of controllers, views, models, clients, services folder. In this server,


1. menu photos will be stored on a publicly accessible folder on S3
2. the api endpoint will be implemented in controllers/api_controller.rb
3. the internal customer support functinality will be implemented under controllers/ics_controllers and view/ics/ related

## Model
- sessions
  + id: int
  + photo_urls: json array of strings
  + lat: double
  + lng: double
  + potential_restaurant_name: string
  + potential_address: string
  + created_at: int
- food_menus
  + id: int
  + created_at: int
- food_menu_items:
  + id: int
  + menu_id: int
  + name: string
  + standarized_name: string
  + price: double
  + category: enum
  + spice: int(1-5)
  + richness: int(1-5)
  + ingredients: json array of enum strings
  + created_at: int
- food_photos
  + id: int
  + standarized_name: string
  + photo_url: string
- enriched_food_menu_items:
  + food_menu_item_id: int
  + description: string
  + tags: json array of enum { code: string, label: string }
  + created_at: int
- wine_menus
  + id: int
  + created_at: int
- wine_menu_items:
  + id: int
  + menu_id: int
  + name: string
  + price_glass double
  + price_bottle: double
  + category: enum
  + created_at: int
- enriched_wine_menu_items:
  + wine_menu_item_id: int
  + grape_varietal: string
  + description: string
  + country: string
  + region: string
  + flavor: enum
  + created_at: int
- restaurants
  + id: int
  + name: string
  + address: string
  + cuisine: string
  + lat: double
  + lng: double
  + food_menu_id: int
  + wine_menu_id: int
  + created_at: int
  + last_updated_at: int
- reviews
  + id: int
  + session_id: int
  + reviewed_at: int

For all the possible enum values, please read the client code base

## Client
- OpenAI
- S3

## Service
- MenuExtractionService (photo to basic information)
  + Use openai to extract information such as is_food, is_wine, name, price, price_bottle, price_glass, ingredients, richness, spicea from food/wine menu photos as well as extracing restaurant name if available
- FoodMenuEnrichmentService (basic information to enriched information)
  + Take a list of food menu items and enrich with information like standardized_name, description, tags, photo_url, etc.
  + for the standardized_name, the service should adaptively create a new standardzied name if no existing standardized name fits the given food item
- WineMenuEnrichmentService (basic information to enriched information)
  + Take a list of wine menu items and enrich with information like country, regino, grape_varietal, description, flavor
- FoodPhotoSynthesizer
  + Take standardized food item name and turn it into a picture for illustrative purpose and displayed on the app

## View
- ics/home.haml: mobile friendly, allow session authenticated users to access internal support functionality. the default username/password (office/OfficeManager!123) can be hardcoded first. 
- ics/sessions.haml:
  + reviewed section and unreviewed section
  + The most important functionlaity right now is for users to review uploaded AI extracted menu information as well as the corresponding photos (edit if needed) as well as associated the menus to the right restaurant.
- ics/restaurants.haml
  + The view should also allow searching existing restaurants by name/address to associate with the menu
- ics/synthesized_photos.haml
  + allow searching existing standardized food item names and view the synthesized photos

## Controller
- api_controller.rb
- ics_controller.rb

