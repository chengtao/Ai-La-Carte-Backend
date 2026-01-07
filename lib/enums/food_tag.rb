module Enums
  module FoodTag
    ALL = {
      'COMMUNITY_FAVORITE' => 'Community Favorite',
      'CHEF_SIGNATURE' => "Chef's Signature",
      'CROWD_PLEASER' => 'Crowd Pleaser',
      'GREAT_VALUE' => 'Great Value'
    }.freeze

    def self.valid?(code)
      ALL.key?(code)
    end

    def self.label(code)
      ALL[code]
    end

    def self.codes
      ALL.keys
    end

    def self.all
      ALL.map { |code, label| { code: code, label: label } }
    end
  end
end
