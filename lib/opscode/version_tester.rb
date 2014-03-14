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

require 'json'
require 'opscode/versions'

module Opscode

  # Simple tester module that can process omnitruck manifest JSON
  # files (either local files, or taken "live" from the production
  # Omnitruck) and validate our version parsing classes against the
  # versions that are currently available.
  module VersionTester

    CLIENT_URL = "http://www.opscode.com/chef/full_client_list"
    SERVER_URL = "http://www.opscode.com/chef/full_server_list"

    def self.current_client_versions
      versions_from_url(CLIENT_URL)
    end

    def self.current_server_versions
      versions_from_url(SERVER_URL)
    end

    def self.versions_from_url(url)
      data = JSON.parse(`curl --silent #{url}`)
      unique_versions(data)
    end

    def self.versions_from_file(file)
      data = JSON.parse(File.read(file))
      unique_versions(data)
    end

    def self.unique_versions(data)
      (data.keys.map do |platform|
         versions = data[platform]
         versions.keys.map do |version|
           architectures = data[platform][version]
           architectures.keys.map do |architecture|
             installers  = data[platform][version][architecture]
             installers.keys
           end
         end
       end).flatten.sort.uniq
    end

    def self.test_with_version(version_class)
      version_strings = current_client_versions | current_server_versions

      valid, invalid = [], []

      version_strings.each do |v|
        begin
          ver = version_class.new(v)
          valid << ver
        rescue
          invalid << v
        end
      end

      puts "Results for #{version_class}"
      puts
      puts "Valid Versions ======================="
      valid.each{|v| show_version_internals(v)}
      puts
      puts "Invalid Versions ====================="
      invalid.each{|v| puts "\t#{v}"}
      puts
    end

    def self.show_version_internals(v)
      puts "\t#{v} = #{v.class}"
      puts "\tmajor      = #{v.major}"
      puts "\tminor      = #{v.minor}"
      puts "\tpatch      = #{v.patch}"
      puts "\tprerelease = #{v.prerelease}"
      puts "\tbuild      = #{v.build}"
      puts
    end

    def self.test_all
      version_strings = current_client_versions | current_server_versions

      valid, invalid = [], []

      # This is horrible, but necessary to sanely handle the current
      # variation we see.
      version_strings.each do |v|
        begin
          if v.start_with?("10.")
            begin
              ver = Opscode::Version::Rubygems.new(v)
              valid << ver
            rescue
              ver = Opscode::Version::GitDescribe.new(v)
              valid << ver
            end
          elsif v.start_with?("11.")
            begin
              ver = Opscode::Version::GitDescribe.new(v)
              valid << ver
            rescue
              begin
                ver = Opscode::Version::OpscodeSemVer.new(v)
                valid << ver
              rescue
                ver = Opscode::Version::SemVer.new(v)
                valid << ver
              end
            end
          end
        rescue
          invalid << v
        end
      end

      puts "Results for All Version Styles"
      puts
      puts "Valid Versions ======================="
      valid.each{|v| show_version_internals(v)}
      puts
      puts "Invalid Versions ====================="
      invalid.each{|v| puts "\t#{v}"}
      puts
      puts "Sorting Order ========================"
      valid.sort.each{|v| puts "\t#{v}"}
      puts
      puts "Releases ============================="
      valid.select(&:release?).sort.each{|v| puts "\t#{v}"}
      puts
      puts "Pre-Releases ========================="
      valid.select(&:prerelease?).sort.each{|v| puts "\t#{v}"}
      puts
      puts "Release Nightlies (Builds) ==========="
      valid.select(&:release_nightly?).sort.each{|v| puts "\t#{v}"}
      puts
      puts "Pre-release Nightlies (Builds) ======="
      valid.select(&:prerelease_nightly?).sort.each{|v| puts "\t#{v}"}
      puts

    end
  end
end

