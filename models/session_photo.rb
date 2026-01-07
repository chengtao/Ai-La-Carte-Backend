# frozen_string_literal: true

class SessionPhoto < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :session

  def before_create
    self.uuid ||= SecureRandom.uuid
    super
  end

  def to_api_hash
    {
      photo_id: uuid,
      url: url
    }
  end
end
