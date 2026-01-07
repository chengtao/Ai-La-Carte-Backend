module Enums
  module FoodIngredient
    ALL = %w[Beef Pork Chicken Seafood Noodle Rice Other].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.all
      ALL
    end
  end
end
