require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'sinatra'
require 'rack/test'

SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), "data"))

# Override config file setting in omnitruck source. Otherwise it will use
# values from config/config.yml and make you a sad.

Omnitruck.set :virtual_path, ''
Omnitruck.set :build_list_v1, File.join(SPEC_DATA, 'build_list_v1.json')
Omnitruck.set :build_server_list_v1, File.join(SPEC_DATA, 'build_server_list_v1.json')
Omnitruck.set :build_list_v2, File.join(SPEC_DATA, 'build_list_v2.json')
Omnitruck.set :build_server_list_v2, File.join(SPEC_DATA, 'build_server_list_v2.json')
Omnitruck.set :aws_access_key_id, ''
Omnitruck.set :aws_secret_access_key, ''
Omnitruck.set :aws_packages_bucket, 'opscode-omnibus-packages-test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  conf.filter_run :focus => true
  conf.run_all_when_everything_filtered = true
  conf.treat_symbols_as_metadata_keys_with_true_values = true
end


