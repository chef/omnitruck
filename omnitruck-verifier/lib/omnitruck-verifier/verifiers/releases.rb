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

require 'omnitruck-verifier/metadata_cache'
require 'omnitruck-verifier/metadata_file'
require 'omnitruck-verifier/package'
require 'omnitruck-verifier/bucket_lister'

module OmnitruckVerifier
  module Verifiers
    class Releases


      def self.run(argv)
        new(argv).run
      end

      attr_reader :invalid_metadata_files
      attr_reader :invalid_packages

      def initialize(argv)
        @metadata_files, @new_files, @existing_files = nil, nil, nil
        @invalid_metadata_files = []
        @invalid_packages = []
        @argv = argv
      end

      def run
        MetadataCache.ensure_created
        puts "total_releases: #{metadata_files.size}"
        puts "known_releases: #{existing_files.size}"
        puts "new_releases: #{new_files.size}"

        fetch_new_release_metadata
        verify_existing_release_metadata
        verify_packages
        error!
      end

      def error!
        if invalid_metadata_files.empty? and invalid_packages.empty?
          puts "metadata_check: ok"
        else
          invalid_metadata_files.each do |metadata|
            puts metadata.explain_error
          end
          invalid_packages.each do |pkg|
            puts pkg.explain_error
          end
          exit 1
        end
      end

      def verify_packages
        puts "known_package_cksums: #{expected_cksums.size}"
        puts "published_packages: #{published_packages.size}"
        puts "release packages: #{release_packages.size}"
        puts "unverifiable_packages: #{published_packages.size - expected_cksums.size}"


        expected_cksums.each do |expected_data|
          relpath = expected_data["relpath"]
          unless pkg_data = published_packages[relpath]
            raise "missing pkg #{relpath}"
          end
          pkg_data.expected_md5 = expected_data["md5"]
          @invalid_packages << pkg_data unless pkg_data.valid_md5?
        end

      end

      def release_packages
        @release_packages ||= published_packages.select {|p| !p.prerelease? }
      end

      def published_packages
        @published_packages ||= Package.all_by_relpath
      end

      def expected_cksums
        @expected_cksums ||= metadata_files.map { |m| m.package_checksums }.flatten
      end

      def fetch_new_release_metadata
        return false if new_files.empty?
        puts "Caching metadata for new releases"
        new_files.each {|f| f.fetch}
      end

      def verify_existing_release_metadata
        return false if existing_files.empty?
        puts "Verifying cached release metadata"
        @invalid_metadata_files = existing_files.select {|f| !f.quick_verify}
        puts "invalid_metadata_files: #{@invalid_metadata_files.size}"
      end


      def metadata_files
        return @metadata_files unless @metadata_files.nil?
        @metadata_files = MetadataFile.all
        @existing_files, @new_files = [], []
        @metadata_files.each do |f|
          if f.cached?
            @existing_files << f
          else
            @new_files << f
          end
        end
      end

      def existing_files
        metadata_files if @existing_files.nil?
        @existing_files
      end

      def new_files
        metadata_files if @existing_files.nil?
        @new_files
      end

    end
  end
end
