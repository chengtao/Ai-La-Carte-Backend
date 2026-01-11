class FoodPhotoSynthesizer
  include AppLogger

  class SynthesisError < StandardError; end

  IMAGE_PROMPT_TEMPLATE = <<~PROMPT.freeze
    A professional food photography image of %s.
    The dish is beautifully plated on an elegant white plate,
    shot from a 45-degree angle with soft natural lighting.
    Restaurant quality presentation, appetizing and delicious looking.
    Shallow depth of field, warm color tones.
    No text, no watermarks, no logos, no people.
  PROMPT

  def initialize(openai_client: nil, s3_client: nil)
    @openai = openai_client || OpenaiClient.new
    @s3 = s3_client || S3Client.new
    logger.debug "FoodPhotoSynthesizer initialized"
  end

  def synthesize(standardized_name)
    logger.info "Starting photo synthesis for '#{standardized_name}'"

    existing = FoodPhoto.where(standardized_name: standardized_name).first
    if existing
      logger.info "Photo already exists for '#{standardized_name}' (id: #{existing.id}), skipping synthesis"
      return existing
    end

    prompt = format(IMAGE_PROMPT_TEMPLATE, standardized_name)
    logger.debug "Generated DALL-E prompt: #{prompt.gsub("\n", ' ').strip}"

    start_time = Time.now
    logger.info "Calling OpenAI DALL-E API for image generation..."

    response = @openai.generate_image(prompt)

    elapsed = (Time.now - start_time).round(2)
    logger.info "OpenAI DALL-E API response received in #{elapsed}s"

    dalle_url = response.dig('data', 0, 'url')
    unless dalle_url
      logger.error "Failed to generate image: no URL in DALL-E response"
      logger.debug "DALL-E response: #{response.inspect}"
      raise SynthesisError, 'Failed to generate image from DALL-E'
    end

    logger.debug "DALL-E generated URL: #{dalle_url[0..100]}..."

    s3_key = "static/food_photos/#{sanitize_filename(standardized_name)}_#{Time.now.to_i}.jpg"
    logger.info "Uploading image to S3: #{s3_key}"

    upload_start = Time.now
    photo_url = @s3.upload_from_url(s3_key, dalle_url)
    upload_elapsed = (Time.now - upload_start).round(2)

    logger.info "S3 upload completed in #{upload_elapsed}s"
    logger.debug "S3 public URL: #{photo_url}"

    food_photo = FoodPhoto.create(
      standardized_name: standardized_name,
      photo_url: photo_url
    )

    logger.info "Created FoodPhoto record (id: #{food_photo.id}) for '#{standardized_name}'"
    food_photo
  rescue OpenaiClient::OpenaiError => e
    logger.error "Image generation failed for '#{standardized_name}': #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise SynthesisError, "Image generation failed: #{e.message}"
  rescue S3Client::S3Error => e
    logger.error "Image upload failed for '#{standardized_name}': #{e.message}"
    logger.error e.backtrace.first(5).join("\n") if e.backtrace
    raise SynthesisError, "Image upload failed: #{e.message}"
  end

  def synthesize_async(standardized_name)
    logger.info "Queuing async photo synthesis for '#{standardized_name}'"
    Thread.new do
      logger.debug "Starting async synthesis thread for '#{standardized_name}'"
      synthesize(standardized_name)
    rescue StandardError => e
      logger.error "Async photo synthesis failed for '#{standardized_name}': #{e.message}"
    end
  end

  def regenerate(standardized_name)
    logger.info "Starting photo regeneration for '#{standardized_name}'"

    existing = FoodPhoto.where(standardized_name: standardized_name).first

    if existing
      logger.info "Found existing photo (id: #{existing.id}), regenerating..."
      old_url = existing.photo_url
      old_key = extract_s3_key(old_url)
      logger.debug "Old S3 key: #{old_key}"

      prompt = format(IMAGE_PROMPT_TEMPLATE, standardized_name)
      logger.debug "Generated DALL-E prompt for regeneration"

      start_time = Time.now
      logger.info "Calling OpenAI DALL-E API for regeneration..."

      response = @openai.generate_image(prompt)

      elapsed = (Time.now - start_time).round(2)
      logger.info "OpenAI DALL-E API response received in #{elapsed}s"

      dalle_url = response.dig('data', 0, 'url')
      unless dalle_url
        logger.error "Failed to regenerate image: no URL in DALL-E response"
        raise SynthesisError, 'Failed to generate image from DALL-E'
      end

      s3_key = "static/food_photos/#{sanitize_filename(standardized_name)}_#{Time.now.to_i}.jpg"
      logger.info "Uploading regenerated image to S3: #{s3_key}"

      photo_url = @s3.upload_from_url(s3_key, dalle_url)

      existing.update(photo_url: photo_url)
      logger.info "Updated FoodPhoto record (id: #{existing.id}) with new URL"

      if old_key
        logger.info "Deleting old S3 object: #{old_key}"
        @s3.delete(old_key)
        logger.debug "Old S3 object deleted successfully"
      end

      logger.info "Photo regeneration completed for '#{standardized_name}'"
      existing
    else
      logger.info "No existing photo found for '#{standardized_name}', creating new one"
      synthesize(standardized_name)
    end
  end

  private

  def sanitize_filename(name)
    name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
  end

  def extract_s3_key(url)
    return nil unless url

    uri = URI.parse(url)
    key = uri.path.sub(%r{^/}, '')
    logger.debug "Extracted S3 key from URL: #{key}"
    key
  rescue URI::InvalidURIError => e
    logger.warn "Failed to extract S3 key from URL '#{url}': #{e.message}"
    nil
  end
end
