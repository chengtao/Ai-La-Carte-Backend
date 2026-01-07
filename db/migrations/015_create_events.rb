# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:events) do
      primary_key :id
      String :session_id
      String :user_id
      String :device_id
      String :event, null: false
      column :meta, :jsonb, default: Sequel.lit("'{}'::jsonb")
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :session_id
      index :user_id
      index :device_id
      index :event
      index :created_at
    end
  end
end
