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

#!/usr/bin/env ruby

RELEASE_RB_PATH = "/mnt/work/omnibus-chef/jenkins/release.rb"
PACKAGES_BUCKET = "opscode-omnibus-packages"
METADATA_BUCKET = "opscode-omnibus-package-metadata"
PROJECT = "chef"

# -p chef -v $CHEF_VERSION-$CHEF_PACKAGE_ITERATION -b opscode-omnitruck-test -m ~/.s3-metadata-upload-cfg -M opscode-omnibus-package-metadata-test

# Sanity checks:
unless File.directory?("s3-client-backup")
  $stderr.puts "you need to run this script from the omnitruck/backup directory"
  $stderr.puts "and have already fetched the client packages"
  exit 1
end

METADATA_S3CMD_CONFIG = File.expand_path("~/.s3-metadata-upload-cfg")
unless File.readable?(METADATA_S3CMD_CONFIG)
  $stderr.puts "You need to configure s3cmd for the metadata account"
  $stderr.puts "config goes in #{METADATA_S3CMD_CONFIG}"
  exit 1
end

PACKAGES_S3CMD_CONFIG = File.expand_path("~/.s3-package-upload-cfg")

unless File.readable?(PACKAGES_S3CMD_CONFIG)
  $stderr.puts "You need to configure s3cmd for the package upload account"
  $stderr.puts "config goes in #{PACKAGES_S3CMD_CONFIG}"
  exit 1
end

Dir["s3-client-backup/*"].each do |release_dir|
  Dir.chdir(release_dir) do
    release_version = File.basename(release_dir)
    puts "** RELEASING #{release_version} **"
    release_cmd = [
      RELEASE_RB_PATH,
      "-c #{PACKAGES_S3CMD_CONFIG}",
      "-p #{PROJECT}",
      "-v #{release_version}",
      "-b #{PACKAGES_BUCKET}",
      "-m #{METADATA_S3CMD_CONFIG}",
      "-M #{METADATA_BUCKET}",
      "--ignore-missing-packages"
    ].join(" ")
    puts release_cmd
    raise "release failed!" unless system(release_cmd)
  end
end
