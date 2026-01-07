class Review < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  many_to_one :session

  def to_api_hash
    {
      id: id,
      session_id: session_id,
      reviewed_at: reviewed_at&.iso8601,
      created_at: created_at&.iso8601
    }
  end
end
