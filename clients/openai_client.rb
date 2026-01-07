require 'httparty'
require 'json'

class OpenaiClient
  BASE_URL = 'https://api.openai.com/v1'.freeze

  class OpenaiError < StandardError; end

  def initialize
    @api_key = ENV.fetch('OPENAI_API_KEY')
  end

  def vision_analyze(image_urls, prompt)
    content = [{ type: 'text', text: prompt }]
    image_urls.each do |url|
      content << { type: 'image_url', image_url: { url: url } }
    end

    response = HTTParty.post(
      "#{BASE_URL}/chat/completions",
      headers: headers,
      body: {
        model: 'gpt-4o',
        messages: [{ role: 'user', content: content }],
        max_tokens: 4096
      }.to_json,
      timeout: 120
    )

    parse_response(response)
  end

  def chat_completion(messages, response_format: nil, model: 'gpt-4o')
    body = {
      model: model,
      messages: messages,
      max_tokens: 4096
    }
    body[:response_format] = response_format if response_format

    response = HTTParty.post(
      "#{BASE_URL}/chat/completions",
      headers: headers,
      body: body.to_json,
      timeout: 60
    )

    parse_response(response)
  end

  def generate_image(prompt, size: '1024x1024', quality: 'standard')
    response = HTTParty.post(
      "#{BASE_URL}/images/generations",
      headers: headers,
      body: {
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: size,
        quality: quality
      }.to_json,
      timeout: 120
    )

    parse_response(response)
  end

  def extract_content(response)
    response.dig('choices', 0, 'message', 'content')
  end

  def extract_json(response)
    content = extract_content(response)
    return nil unless content

    json_str = content.match(/```json\n?(.*?)\n?```/m)&.[](1) || content
    JSON.parse(json_str, symbolize_names: true)
  rescue JSON::ParserError => e
    raise OpenaiError, "Failed to parse JSON response: #{e.message}"
  end

  private

  def headers
    {
      'Authorization' => "Bearer #{@api_key}",
      'Content-Type' => 'application/json'
    }
  end

  def parse_response(response)
    body = response.parsed_response

    if body.is_a?(Hash) && body['error']
      raise OpenaiError, body['error']['message']
    end

    unless response.success?
      raise OpenaiError, "API request failed with status #{response.code}"
    end

    body
  end
end
