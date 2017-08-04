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
require 'rspec/its'

SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), "data"))

# Override config file setting in omnitruck source. Otherwise it will use
# values from config/config.yml and make you a sad.

Omnitruck.set :virtual_path, ''
Omnitruck.set :metadata_dir, SPEC_DATA

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  conf.filter_run :focus => true
  conf.run_all_when_everything_filtered = true
  conf.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Uncomment to write failed specs to file.
  # Run failed tests using --only-failures flag
  # conf.example_status_persistence_file_path = "examples.txt"
end
