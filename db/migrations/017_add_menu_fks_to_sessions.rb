# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:sessions) do
      add_foreign_key :food_menu_id, :food_menus, on_delete: :set_null
      add_foreign_key :wine_menu_id, :wine_menus, on_delete: :set_null
    end
  end
end
