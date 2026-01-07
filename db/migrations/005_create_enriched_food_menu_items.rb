Sequel.migration do
  change do
    create_table(:enriched_food_menu_items) do
      foreign_key :food_menu_item_id, :food_menu_items, primary_key: true, on_delete: :cascade
      String :description, text: true
      column :tags, :jsonb, default: Sequel.pg_jsonb([])
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
