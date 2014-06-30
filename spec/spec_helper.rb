#--
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'sinatra'
require 'rack/test'

SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), "data"))

# Override config file setting in omnitruck source. Otherwise it will use
# values from config/config.yml and make you a sad.

Omnitruck.set :virtual_path, ''
Omnitruck.set :build_list_v1, File.join(SPEC_DATA, 'build_list_v1.json')
Omnitruck.set :build_server_list_v1, File.join(SPEC_DATA, 'build_server_list_v1.json')
Omnitruck.set :build_chefdk_list_v1, File.join(SPEC_DATA, 'build_chefdk_list_v1.json')
Omnitruck.set :build_container_list_v1, File.join(SPEC_DATA, 'build_container_list_v1.json')
Omnitruck.set :build_list_v2, File.join(SPEC_DATA, 'build_list_v2.json')
Omnitruck.set :build_server_list_v2, File.join(SPEC_DATA, 'build_server_list_v2.json')
Omnitruck.set :build_chefdk_list_v2, File.join(SPEC_DATA, 'build_chefdk_list_v2.json')
Omnitruck.set :build_container_list_v2, File.join(SPEC_DATA, 'build_container_list_v2.json')
Omnitruck.set :aws_access_key_id, ''
Omnitruck.set :aws_secret_access_key, ''
Omnitruck.set :aws_packages_bucket, 'opscode-omnibus-packages-test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  conf.filter_run :focus => true
  conf.run_all_when_everything_filtered = true
  conf.treat_symbols_as_metadata_keys_with_true_values = true
end
