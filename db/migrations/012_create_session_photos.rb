# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:session_photos) do
      primary_key :id
      String :uuid, null: false, unique: true
      foreign_key :session_id, :sessions, null: false, on_delete: :cascade
      String :url, null: false
      String :s3_key, null: false
      String :content_type, default: 'image/jpeg'
      Integer :file_size
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :session_id
      index :uuid
    end
  end
end
