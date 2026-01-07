# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:feedback) do
      primary_key :id
      foreign_key :session_id, :sessions, null: false, on_delete: :cascade
      String :item_id, null: false
      String :item_type, null: false
      String :action, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :session_id
      index [:item_id, :item_type]
    end
  end
end
