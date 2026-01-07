Sequel.migration do
  change do
    create_table(:enriched_wine_menu_items) do
      foreign_key :wine_menu_item_id, :wine_menu_items, primary_key: true, on_delete: :cascade
      String :grape_varietal
      String :description, text: true
      String :country
      String :region
      String :flavor
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
