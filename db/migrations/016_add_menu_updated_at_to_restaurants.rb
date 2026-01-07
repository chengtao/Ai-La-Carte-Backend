# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:restaurants) do
      add_column :menu_updated_at, DateTime
    end
  end
end
