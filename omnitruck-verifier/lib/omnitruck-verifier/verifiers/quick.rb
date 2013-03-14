require 'optparse'
require 'omnitruck-verifier/metadata_cache'
require 'omnitruck-verifier/metadata_file'
require 'omnitruck-verifier/package'
require 'omnitruck-verifier/bucket_lister'

module OmnitruckVerifier
  module Verifiers
    class Quick


      def self.run(argv)
        new(argv).run
      end

      attr_reader :invalid_metadata_files
      attr_reader :invalid_packages
      attr_reader :options

      def initialize(argv)
        @metadata_files, @new_files, @existing_files = nil, nil, nil
        @invalid_metadata_files = []
        @invalid_packages = []
        @argv = argv
        @options = {}
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

      def parse_opts
        option_parser.parse(@argv)
      end

      def run
        parse_opts

        MetadataCache.ensure_created
        msg "total_releases: #{metadata_files.size}"
        msg "known_releases: #{existing_files.size}"
        msg "new_releases: #{new_files.size}"

        fetch_new_release_metadata
        verify_existing_release_metadata
        verify_packages
        error!
      end

      def error!
        # Some checksums did not match?
        if !(invalid_packages.empty? && invalid_metadata_files.empty?)
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

      def success_message
        if nagios_mode?
          puts "OK: All packages match checksums"
        else
          msg "metadata_check: ok"
        end
      end

      def unverifiable_packages_message
        if nagios_mode?
          puts "CRIT: available metadata ok, but #{unverifiable_package_count} packages cannot be verified"
        else
          msg "unverifiable_packages: #{unverifiable_package_count}"
        end
      end

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

      def nagios_mode?
        options[:nagios]
      end

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

      def unverifiable_package_count
        published_packages.size - expected_cksums.size
      end

      def published_packages
        @published_packages ||= Package.all_by_relpath
      end

      def expected_cksums
        @expected_cksums ||= metadata_files.map { |m| m.package_checksums }.flatten
      end

      def fetch_new_release_metadata
        return false if new_files.empty?
        msg "Caching metadata for new releases"
        new_files.each {|f| f.fetch}
      end

      def verify_existing_release_metadata
        return false if existing_files.empty?
        msg "Verifying cached release metadata"
        @invalid_metadata_files = existing_files.select {|f| !f.quick_verify}
        msg "invalid_metadata_files: #{@invalid_metadata_files.size}"
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
