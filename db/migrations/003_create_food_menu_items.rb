Sequel.migration do
  change do
    create_table(:food_menu_items) do
      primary_key :id
      foreign_key :menu_id, :food_menus, on_delete: :cascade
      String :name, null: false
      String :standardized_name
      Float :price
      String :category, default: 'other'
      Integer :spice
      Integer :richness
      column :ingredients, :jsonb, default: Sequel.pg_jsonb([])
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :menu_id
      index :standardized_name
    end
  end
end
