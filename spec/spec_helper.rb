require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'sinatra'
require 'rack/test'

SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), "data"))

Sinatra::Base.set :virtual_path, ''
Sinatra::Base.set :build_list, File.join(SPEC_DATA, "build_list.json")
Sinatra::Base.set :build_server_list, File.join(SPEC_DATA, "build_server_list.json")
Sinatra::Base.set :aws_access_key_id, ''
Sinatra::Base.set :aws_secret_access_key, ''
Sinatra::Base.set :aws_bucket, 'opscode-omnitruck-test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  conf.filter_run :focus => true
  conf.run_all_when_everything_filtered = true
  conf.treat_symbols_as_metadata_keys_with_true_values = true
end


