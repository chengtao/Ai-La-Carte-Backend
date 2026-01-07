Sequel.migration do
  change do
    create_table(:food_menus) do
      primary_key :id
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
