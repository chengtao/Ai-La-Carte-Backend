# frozen_string_literal: true

Sequel.migration do
  up do
    # Add UUID column
    alter_table(:sessions) do
      add_column :uuid, :uuid
    end

    # Populate existing records with generated UUIDs
    run "UPDATE sessions SET uuid = gen_random_uuid() WHERE uuid IS NULL"

    # Make UUID non-null and unique
    alter_table(:sessions) do
      set_column_not_null :uuid
      add_unique_constraint :uuid
      add_index :uuid
    end
  end

  down do
    alter_table(:sessions) do
      drop_index :uuid
      drop_column :uuid
    end
  end
end
