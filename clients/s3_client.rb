require 'aws-sdk-s3'
require 'httparty'

class S3Client
  class S3Error < StandardError; end

  def initialize
    @bucket = ENV.fetch('S3_BUCKET')
    @region = ENV.fetch('AWS_REGION', 'us-east-1')
    @client = Aws::S3::Client.new(
      region: @region,
      access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
      secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY')
    )
    @resource = Aws::S3::Resource.new(client: @client)
  end

  def upload(key, file_or_io, content_type: 'image/jpeg', acl: 'public-read')
    obj = @resource.bucket(@bucket).object(key)
    obj.put(
      body: file_or_io,
      content_type: content_type,
      acl: acl
    )
    obj.public_url
  end

  def upload_from_url(key, source_url, content_type: 'image/jpeg')
    response = HTTParty.get(source_url, timeout: 60)
    raise S3Error, "Failed to download from: #{source_url}" unless response.success?

    upload(key, response.body, content_type: content_type)
  end

  def delete(key)
    @client.delete_object(bucket: @bucket, key: key)
    true
  rescue Aws::S3::Errors::ServiceError => e
    raise S3Error, "Failed to delete object: #{e.message}"
  end

  def exists?(key)
    @client.head_object(bucket: @bucket, key: key)
    true
  rescue Aws::S3::Errors::NotFound
    false
  end

  def public_url(key)
    "https://#{@bucket}.s3.#{@region}.amazonaws.com/#{key}"
  end

  def presigned_upload_url(key, content_type: 'image/jpeg', expires_in: 3600)
    signer = Aws::S3::Presigner.new(client: @client)
    signer.presigned_url(
      :put_object,
      bucket: @bucket,
      key: key,
      content_type: content_type,
      expires_in: expires_in,
      acl: 'public-read'
    )
  end

  def presigned_get_url(key, expires_in: 3600)
    signer = Aws::S3::Presigner.new(client: @client)
    signer.presigned_url(
      :get_object,
      bucket: @bucket,
      key: key,
      expires_in: expires_in
    )
  end
end
