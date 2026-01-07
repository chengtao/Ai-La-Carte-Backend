Sequel.migration do
  change do
    create_table(:reviews) do
      primary_key :id
      foreign_key :session_id, :sessions, null: false, unique: true, on_delete: :cascade
      DateTime :reviewed_at, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :session_id
    end
  end
end
