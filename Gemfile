source 'https://rubygems.org'
ruby '3.2.2'

# Web Framework
gem 'sinatra', '~> 3.0'
gem 'sinatra-contrib', '~> 3.0'
gem 'puma', '~> 6.0'

# Views
gem 'haml', '~> 6.0'

# Database
gem 'sequel', '~> 5.0'
gem 'pg', '1.5.4'  # Pinned: 1.6.x has segfault issues on Apple Silicon

# AWS
gem 'aws-sdk-s3', '~> 1.0'

# HTTP Client (for OpenAI)
gem 'httparty', '~> 0.21'

# Environment
gem 'dotenv', '~> 2.8'

# JSON
gem 'oj', '~> 3.16'
gem 'multi_json', '~> 1.15'

# Security
gem 'rack-protection', '~> 3.0'

group :development do
  gem 'rerun', '~> 0.14'
  gem 'pry', '~> 0.14'
  gem 'pry-byebug'
  gem "pry-rescue"
end

group :test do
  gem 'rspec', '~> 3.12'
  gem 'rack-test', '~> 2.1'
  gem 'database_cleaner-sequel', '~> 2.0'
  gem 'factory_bot', '~> 6.2'
  gem 'webmock', '~> 3.19'
end
