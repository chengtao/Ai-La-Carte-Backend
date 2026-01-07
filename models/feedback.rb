# frozen_string_literal: true

class Feedback < Sequel::Model(:feedback)
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :session

  ACTIONS = %w[loved disliked not_ordered].freeze
  ITEM_TYPES = %w[food wine].freeze

  def validate
    super
    errors.add(:action, 'invalid action') unless ACTIONS.include?(action)
    errors.add(:item_type, 'invalid item type') unless ITEM_TYPES.include?(item_type)
  end

  def to_api_hash
    {
      id: id,
      item_id: item_id,
      item_type: item_type,
      action: action,
      created_at: created_at&.iso8601
    }
  end
end
