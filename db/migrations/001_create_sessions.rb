Sequel.migration do
  change do
    create_table(:sessions) do
      primary_key :id
      column :photo_urls, :jsonb, null: false, default: Sequel.pg_jsonb([])
      Float :lat
      Float :lng
      String :potential_restaurant_name
      String :potential_address
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
