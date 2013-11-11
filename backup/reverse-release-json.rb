#--
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Opscode, Inc.
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

# Author Tyler Cloke <tyler@opscode.com>
#
# Reverses omnibus-chef/jenkins/chef.json or chef-server.json from format:
# 
#"build_os=centos-5,machine_architecture=x64,role=oss-builder": [
#       [
#            "el",
#            "5",
#            "x86_64"
#        ]
#
# to format:
# "el": {
#    "5": {
#      "x86_64": "build_os=centos-5,machine_architecture=x64,role=oss-builder",
#      "i686": "build_os=centos-5,machine_architecture=x86,role=oss-builder"
#    }
#
# and outputs to "reversed.json"
require 'json'

json = {}
input = JSON.parse(File.read(ARGV[0]))
input.each do |key, array|
  array.each do |block|
    json[block[0]] ||= {}
    json[block[0]][block[1]] ||= {}
    json[block[0]][block[1]][block[2]] ||= {}
    json[block[0]][block[1]][block[2]] = key
  end
end

File.open("reversed.json", "w") do |f|
  f.write(JSON.pretty_generate(json))
end


