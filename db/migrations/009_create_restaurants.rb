Sequel.migration do
  change do
    create_table(:restaurants) do
      primary_key :id
      String :name, null: false
      String :address
      String :cuisine
      Float :lat
      Float :lng
      foreign_key :food_menu_id, :food_menus, on_delete: :set_null
      foreign_key :wine_menu_id, :wine_menus, on_delete: :set_null
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :last_updated_at

      index [:lat, :lng]
      index :name
    end
  end
end
