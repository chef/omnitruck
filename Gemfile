source 'https://rubygems.org'

# tracking master because of this bug:
# https://github.com/sinatra/sinatra/pull/805
# once 1.4.5 is released, this should stop
gem 'sinatra', :git => 'https://github.com/sinatra/sinatra.git', :branch => 'master'
gem 'sinatra-contrib'
gem 'uber-s3'
gem 'unicorn'
gem 'json'
gem 'colorize'
gem 'yajl-ruby'
gem "rest-client"
gem 'nokogiri'
gem 'rake'
gem 'mixlib-versioning', '~> 1.1.0'
gem 'trashed'

group :test do
  gem 'rspec'
  gem 'rspec-legacy_formatters'
  gem 'rspec-rerun', '~> 0.3.0'
  gem 'rspec-its'
  gem 'rack-test'
  gem 'rspec_junit_formatter'
end

group :security do
  gem 'bundler-audit'
end
