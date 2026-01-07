module Enums
  module WineCategory
    ALL = %w[sparkling white rose red sweet other].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.all
      ALL
    end
  end
end
