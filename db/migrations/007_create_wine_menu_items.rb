Sequel.migration do
  change do
    create_table(:wine_menu_items) do
      primary_key :id
      foreign_key :menu_id, :wine_menus, on_delete: :cascade
      String :name, null: false
      Float :price_glass
      Float :price_bottle
      String :category, default: 'other'
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :menu_id
    end
  end
end
