module Enums
  module FoodCategory
    ALL = %w[appetizer soup entree seafood dessert other].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.all
      ALL
    end
  end
end
