module Enums
  module WineFlavor
    ALL = ['Elegant', 'Fruity', 'Full-Body', 'Sweet', 'Acidic'].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.all
      ALL
    end
  end
end
