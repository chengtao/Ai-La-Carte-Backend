# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:jobs) do
      primary_key :id
      String :uuid, null: false, unique: true
      foreign_key :session_id, :sessions, null: false, on_delete: :cascade
      String :status, null: false, default: 'created'
      Float :progress, null: false, default: 0.0
      String :error_message
      Float :lat
      Float :lng
      foreign_key :food_menu_id, :food_menus, on_delete: :set_null
      foreign_key :wine_menu_id, :wine_menus, on_delete: :set_null
      DateTime :started_at
      DateTime :completed_at
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at

      index :session_id
      index :uuid
      index :status
    end
  end
end
