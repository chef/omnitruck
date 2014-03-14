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

# gen_v2_data.rb
# usage: ruby gen_v2_data.rb V1_FILE
# (prints to stdout)
# To write generated v2 data for use w/ specs:
# ruby gen_v2_data.rb V1_FILE > V2_FILE

require 'rubygems'
require 'yajl'
require 'digest'
require 'stringio'
require 'pp'

def md5(string)
  digest(Digest::MD5, StringIO.new(string))
end

def sha256(string)
  digest(Digest::SHA256, StringIO.new(string))
end

def digest(digest_class, io)
  digest = digest_class.new
  while chunk = io.read(1024 * 8)
    digest.update(chunk)
  end
  digest.hexdigest
end


v1_client = Yajl::Parser.parse(ARGF.read)
v1_client.delete("run_data")
v1_client.each_value do |builds_by_distro_version|
  builds_by_distro_version.each_value do |builds_by_arch|
    builds_by_arch.each_value do |pkgs_by_version|
      pkgs_by_version.each do |pkg_ver, relpath|
        v2_data = {:relpath => relpath, :md5 => md5(relpath), :sha256 => sha256(relpath) }
        pkgs_by_version[pkg_ver] = v2_data
      end
    end
  end
end

begin
  puts Yajl::Encoder.encode(v1_client, :pretty => true)
rescue Errno::EPIPE
  exit 0
end
