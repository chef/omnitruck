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

require 'optparse'
require 'omnitruck-verifier/metadata_cache'
require 'omnitruck-verifier/metadata_file'
require 'omnitruck-verifier/package'
require 'omnitruck-verifier/bucket_lister'

module OmnitruckVerifier
  module Verifiers
    class Quick


      # Convenience wrapper for creating a new Verifiers::Quick object and
      # running it.
      def self.run(argv)
        new(argv).run
      end

      attr_reader :invalid_metadata_files
      attr_reader :invalid_packages
      attr_reader :options

      # Create a new Verifiers::Quick object. +argv+ is expected to be an Array
      # of strings (e.g., ARGV).
      def initialize(argv)
        @metadata_files, @new_files, @existing_files = nil, nil, nil
        @invalid_metadata_files = []
        @invalid_packages = []
        @argv = argv
        @options = {}
        @exception = nil
      end

      def option_parser
        @option_parser ||= begin
          OptionParser.new do |opts|

            opts.banner = "verify-quick [OPTIONS]"

            opts.on("-N", "--nagios", "Nagios compatible output mode") do |v|
              options[:nagios] = v
            end

            opts.on("-c CACHE_DIR", "--cache-dir CACHE_DIR", "Directory where metadata files are cached. Default: ~/.omnibus-verify") do |c|
              MetadataCache.cache_dir = c
            end

            opts.on_tail("-h", "--help", "Display help") do
              puts opts
              exit 1
            end

          end
        end
      end

      # Parse command line options (as specified by +argv+ passed to the
      # constructor)
      def parse_opts
        option_parser.parse(@argv)
      end

      # Main entry point. Updates the metadata cache with any new metadata
      # files that have been published, then lists all of the packages in S3
      # and compares the MD5 given by S3 with the "correct" one in the
      # metadata. Metadata files are themselves checked for correct MD5 as
      # well. Diagnostic information is printed to STDOUT, though the format
      # varies depending on user-supplied options.
      #
      # This method exits the program when finished.
      def run
        parse_opts

        begin
          MetadataCache.ensure_created
          msg "total_releases: #{metadata_files.size}"
          msg "known_releases: #{existing_files.size}"
          msg "new_releases: #{new_files.size}"

          fetch_new_release_metadata
          verify_existing_release_metadata
          verify_packages
        rescue Exception => e
          @exception = e
        ensure
          error!
        end
      end

      # Writes an error or success message and exits the program.
      def error!
        # Unhandled exception
        if @exception
          exception_message
          exit 2
        # Some checksums did not match?
        elsif !(invalid_packages.empty? && invalid_metadata_files.empty?)
          error_message
          exit 2
        # We don't have checksums for some packages?
        elsif unverifiable_package_count != 0
          unverifiable_packages_message
          exit 2
        else
          success_message
          exit 0
        end
      end

      # Writes a success message. Exact output depends on whether nagios mode
      # is enabled.
      def success_message
        if nagios_mode?
          puts "OK: All packages match checksums"
        else
          msg "metadata_check: ok"
        end
      end

      # Writes an error message explaining that some unverifiable packages
      # exist. Output depends on whether nagios mode is enabled.
      def unverifiable_packages_message
        if nagios_mode?
          puts "CRIT: available metadata ok, but #{unverifiable_package_count} packages cannot be verified"
        else
          msg "unverifiable_packages: #{unverifiable_package_count}"
          unverifiable_packages.each do |pkg|
            msg "* #{pkg}"
          end
        end
      end

      # Writes an error message. Exact output varies depending on whether
      # nagios mode is enabled.
      def error_message
        if nagios_mode?
          puts "CRIT: #{invalid_metadata_files.size} metadata files and #{invalid_packages.size} packages with invalid checksums"
        else
          invalid_metadata_files.each do |metadata|
            msg metadata.explain_error
          end
          invalid_packages.each do |pkg|
            msg pkg.explain_error
          end
        end
      end

      def exception_message
        if nagios_mode?
          puts "CRIT: unhandled exception in package verification: #{@exception}"
        else
          puts "#{@exception.class}: #{@exception}"
          puts @exception.backtrace.map {|l| "\t#{l}" }
        end
      end

      # True if Nagios format output is configured, false otherwise.
      def nagios_mode?
        options[:nagios]
      end

      # Emit a message to STDOUT, when not in nagios mode.
      def msg(message)
        puts message unless nagios_mode?
      end

      def verify_packages
        msg "known_package_cksums: #{expected_cksums.size}"
        msg "published_packages: #{published_packages.size}"


        expected_cksums.each do |expected_data|
          relpath = expected_data["relpath"]
          unless pkg_data = published_packages[relpath]
            raise "missing pkg #{relpath}"
          end
          pkg_data.expected_md5 = expected_data["md5"]
          @invalid_packages << pkg_data unless pkg_data.valid_md5?
        end

      end

      # Returns an Integer number of packages that exist in S3 but do not have
      # any metadata entry.
      def unverifiable_package_count
        published_packages.size - expected_cksums.size
      end

      # Gives an Array of package objects that do not have any corresponding
      # metadata entries (as determined by comparing with #expected_cksums)
      def unverifiable_packages
        published_packages.keys.select {|p| !expected_cksums.any? {|m| m["relpath"] == p } }
      end

      # Gives a Hash of Package objects representing all packages found by
      # listing the packages S3 bucket. The Hash keys are the relative paths to
      # the package (s3 object keys).
      #
      # === Return Type:
      # { "$distro/$distro_version/$cpu_arch/$package_name" => Package, ... }
      def published_packages
        @published_packages ||= Package.all_by_relpath
      end

      # Gives an Array of Hashes containing the metadata (with expected md5 and
      # sha256) of all packages for which metadata is available. The result is
      # generated such that packages with more than one platform (e.g., we
      # build sparc packages on Solaris 9 and distribute them for all Solaris
      # versions) will only appear once in the result.
      #
      # === Return Type:
      # [ {"relpath" => "$distro/$distro_version/$cpu_arch/$package_name",
      #    "md5"     => "$pkg_md5",
      #    "sha256"  => "$pkg_sha256" }, ... ]
      def expected_cksums
        @expected_cksums ||= begin
          expected_cksums_by_relpath = {}
          metadata_with_duplicates = metadata_files.map { |m| m.package_checksums }.flatten
          metadata_with_duplicates.each do |metadata|
            expected_cksums_by_relpath[metadata["relpath"]] ||= metadata
          end
          expected_cksums_by_relpath.values
        end
      end

      # Iterates of the list of #new_files, downloading the files from S3 to
      # the local metadata cache.
      def fetch_new_release_metadata
        return false if new_files.empty?
        msg "Caching metadata for new releases"
        new_files.each {|f| f.fetch}
      end

      # Iterates over the list of #existing_files verifying their MD5 checksums
      # against the MD5 returned by S3.
      def verify_existing_release_metadata
        return false if existing_files.empty?
        msg "Verifying cached release metadata"
        @invalid_metadata_files = existing_files.select {|f| !f.quick_verify}
        msg "invalid_metadata_files: #{@invalid_metadata_files.size}"
      end


      # Returns an Array of MetadataFile objects representing all known
      # metadata files. When first called, it also collects Arrays of existing
      # (already cached) and new metadata files.
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

      # Returns an Array of MetadataFile objects representing metadata files
      # that have already been cached locally.
      def existing_files
        metadata_files if @existing_files.nil?
        @existing_files
      end

      # Returns an Array of MetadataFile objects representing metadata files
      # that have not yet been cached locally.
      def new_files
        metadata_files if @existing_files.nil?
        @new_files
      end

    end
  end
end
