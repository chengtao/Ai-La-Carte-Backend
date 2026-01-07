# frozen_string_literal: true

class Event < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  def meta_hash
    case meta
    when Hash then meta
    when String then JSON.parse(meta)
    else {}
    end
  rescue JSON::ParserError
    {}
  end

  def to_api_hash
    {
      id: id,
      session_id: session_id,
      user_id: user_id,
      device_id: device_id,
      event: event,
      meta: meta_hash,
      created_at: created_at&.iso8601
    }
  end
end
