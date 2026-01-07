class FoodPhotoSynthesizer
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
  end

  def synthesize(standardized_name)
    existing = FoodPhoto.where(standardized_name: standardized_name).first
    return existing if existing

    prompt = format(IMAGE_PROMPT_TEMPLATE, standardized_name)
    response = @openai.generate_image(prompt)

    dalle_url = response.dig('data', 0, 'url')
    raise SynthesisError, 'Failed to generate image from DALL-E' unless dalle_url

    s3_key = "food_photos/#{sanitize_filename(standardized_name)}_#{Time.now.to_i}.jpg"
    photo_url = @s3.upload_from_url(s3_key, dalle_url)

    FoodPhoto.create(
      standardized_name: standardized_name,
      photo_url: photo_url
    )
  rescue OpenaiClient::OpenaiError => e
    raise SynthesisError, "Image generation failed: #{e.message}"
  rescue S3Client::S3Error => e
    raise SynthesisError, "Image upload failed: #{e.message}"
  end

  def synthesize_async(standardized_name)
    Thread.new do
      synthesize(standardized_name)
    rescue StandardError => e
      warn "Async photo synthesis failed for #{standardized_name}: #{e.message}"
    end
  end

  def regenerate(standardized_name)
    existing = FoodPhoto.where(standardized_name: standardized_name).first

    if existing
      old_url = existing.photo_url
      old_key = extract_s3_key(old_url)

      prompt = format(IMAGE_PROMPT_TEMPLATE, standardized_name)
      response = @openai.generate_image(prompt)

      dalle_url = response.dig('data', 0, 'url')
      raise SynthesisError, 'Failed to generate image from DALL-E' unless dalle_url

      s3_key = "food_photos/#{sanitize_filename(standardized_name)}_#{Time.now.to_i}.jpg"
      photo_url = @s3.upload_from_url(s3_key, dalle_url)

      existing.update(photo_url: photo_url)

      @s3.delete(old_key) if old_key

      existing
    else
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
    uri.path.sub(%r{^/}, '')
  rescue URI::InvalidURIError
    nil
  end
end
