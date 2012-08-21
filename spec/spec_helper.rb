require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'sinatra'
require 'rack/test'

Sinatra::Base.set :base_url, 'http://localhost:9393/'
Sinatra::Base.set :build_list, './build_list.json'
Sinatra::Base.set :aws_access_key_id, ''
Sinatra::Base.set :aws_secret_access_key, ''
Sinatra::Base.set :aws_bucket, 'opscode-omnitruck-test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end


