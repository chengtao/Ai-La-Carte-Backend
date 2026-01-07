Sequel.migration do
  change do
    create_table(:food_photos) do
      primary_key :id
      String :standardized_name, null: false, unique: true
      String :photo_url, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :standardized_name
    end
  end
end
