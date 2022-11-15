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

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  conf.filter_run :focus => true
  conf.run_all_when_everything_filtered = true
  conf.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def real_projects
    @real_projects ||= (
      Chef::Cache::KNOWN_PROJECTS - [
        'chef-foundation', #TODO - remove once live
        'chef-server-ha-provisioning',
        'chef-universal', #TODO - remove once live
        'ha',
        'harmony',
        'mac-bootstrapper',
        'omnibus-gcc',
        'sync',
      ])
  end

  def spec_data_record(c, project, p, pv, m, v)
    JSON.parse(File.read(File.join(SPEC_DATA, c, "#{project}-manifest.json")))[p][pv][m][v]
  rescue NoMethodError
    raise "Could not find spec data record for #{c}/#{project}/#{p}/#{pv}/#{m}/#{v}"
  end

  #
  # make sure to update these versions when you regenerate the spec data
  #

  def latest_stable_chef
    '17.10.3'
  end

  def latest_stable_chefdk
    '4.13.3'
  end

  def latest_stable_chef_server
    '14.15.10'
  end

  def latest_stable_chef_workstation
    '22.5.923'
  end

  def latest_current_chef
    '18.0.92'
  end

  def latest_current_chef_workstation
    '22.6.967'
  end

  # Uncomment to write failed specs to file.
  # Run failed tests using --only-failures flag
  # conf.example_status_persistence_file_path = "examples.txt"
end

class MockRedis
  # This fakes our use of redis by loading the data from predefined test
  # fixtures in the data/ directory
  def get(key)
    File.read(File.join(SPEC_DATA, "#{key}-manifest.json"))
  end

  def set(key, value)
    raise NotImplementedError
  end
end

Redis = MockRedis
