source 'https://rubygems.org'

gem 'sinatra', '~> 1.4.7'
gem 'sinatra-contrib'
gem 'unicorn'
gem 'json'
gem 'colorize'
gem 'yajl-ruby'
gem "rest-client"
gem 'rake'
gem 'mixlib-versioning', '~> 1.1.0'
# TODO: Release mixlib-install and set the ~> version
gem 'mixlib-install', :git => 'https://github.com/chef/mixlib-install.git', :branch => 'pw/known_omnibus_projects'
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
