require 'chef/version'
require 'platform_dsl'

class Chef
  class VersionResolver
    class InvalidDownloadPath < StandardError; end
    class InvalidPlatform < StandardError; end

    # Resolves a version and returns the following information for the found
    # package(s).
    # {
    #   url:      "",
    #   md5:      "",
    #   sha256:   "",
    #   version:  ""
    # }

    attr_reader :dsl
    attr_reader :friendly_error_msg

    attr_reader :build_map
    attr_reader :target_version

    def initialize(version_string, build_map)
      @dsl = PlatformDSL.new()
      dsl.from_file("platforms.rb")
      @build_map = build_map
      @target_version = parse_version_string(version_string)
    end

    def package_info(platform_string, platform_version_string, machine_string)
      @friendly_error_msg = "No installer for platform #{platform_string}, platform_version #{platform_version_string}, machine #{machine_string}"

      target_platform = find_platform_version(platform_string, platform_version_string)

      version_metadata = find_raw_metadata_for(target_platform, machine_string)
      version = find_target_version_in(version_metadata)

      if version.nil?
        raise InvalidDownloadPath, "Cannot find a valid chef version that matches version constraints: #{friendly_error_msg}"
      end

      version
    end

    def package_list
      # We will walk through the build_map and return the matching
      # version for all available platform, platform_version and architecture
      target_versions = {}

      # Overtime we have stopped publishing versions for some platforms. We
      # would like to make sure that we are returning a consistent version
      # across all platforms that is we do not want to return 12.4.3 for a
      # platform and 12.0.3 for others. So we keep track of the latest version
      # and drop all the versions smaller than that.
      latest_version = nil

      build_map.each do |platform, platform_data|
        next if platform == 'run_data'

        platform_data.each do |platform_version, platform_version_data|
          platform_version_data.each do |architecture, raw_metadata|
            version_metadata = find_target_version_in(raw_metadata)

            unless version_metadata.nil?
              version = parse_version_string(version_metadata['version'])
              if latest_version.nil? || latest_version <= version
                latest_version = version

                target_versions[platform] ||= {}
                target_versions[platform][platform_version] ||= {}
                target_versions[platform][platform_version][architecture] = version_metadata
              end
            end
          end
        end
      end

      # We might still have versions other than the latest_version in our map.
      # Let's drop all the other versions.
      output = {}
      target_versions.each do |p, p_data|
        p_data.each do |pv, pv_data|
          pv_data.each do |m, metadata|
            if metadata['version'] == latest_version.to_s
              output[p] ||= {}
              output[p][pv] ||= {}
              output[p][pv][m] = metadata
            end
          end
        end
      end

      output
    end

    # Finds the raw metadata info for the given platform, platform_version
    # and machine_architecture
    def find_raw_metadata_for(target_platform, target_architecture)
      # omnitruck has some core platforms like ubuntu, windows, ...
      # and some secondary platforms that map onto core platforms like linuxmint, scientific
      # mapped_name will return the original name if it is not mapped
      core_platform = target_platform.mapped_name

      # first make sure we have some builds available for the given platform
      if !build_map[core_platform]
        raise InvalidDownloadPath, "Cannot find any chef versions for core platform #{core_platform}: #{friendly_error_msg}"
      end

      # get all the available distro versions
      distro_versions_available = build_map[core_platform].keys

      # select only the packages from the distro versions that are <= the version we are looking for
      # we do not want to select el7 packages for el6 platform
      distro_versions_available.select! {|v| dsl.new_platform_version(core_platform, v) <= target_platform }

      if distro_versions_available.length == 0
        raise InvalidDownloadPath, "Cannot find any available chef versions for this platform version #{target_platform.mapped_name} #{target_platform.mapped_version}: #{friendly_error_msg}"
      end

      # sort the available distro versions from earlier to later: 10.04 then 10.10 etc.
      distro_versions_available.sort! {|v1,v2| dsl.new_platform_version(core_platform, v1) <=> dsl.new_platform_version(core_platform, v2) }

      # Now filter out the metadata based on architecture
      raw_metadata = { }
      distro_versions_available.each do |version|
        next if build_map[core_platform][version][target_architecture].nil?

        # Note that we do not want to make a deep merge here. We want the
        # information coming from the build_map override the ones that are
        # already in raw_metadata because we have sorted
        # distro_versions_available and the later ones will be the correct ones.
        raw_metadata.merge!(build_map[core_platform][version][target_architecture])
      end

      raw_metadata
    end

    # Get raw metadata in the form below:
    # "10.12.0-1": {
    #   "relpath": "/el/6/x86_64/chef-10.12.0-1.el6.x86_64.rpm",
    #   "md5": "abd5482366275f06245c54b2d8b83b04",
    #   "sha256": "5260a494b5616325b9cda49a99c23f2238ba2119c8248988ce09a32e9cca56dd"
    # },
    # "10.14.0-1": {
    #   "relpath": "/el/6/x86_64/chef-10.14.0-1.el6.x86_64.rpm",
    #   "md5": "5c8a8977f69af9c25a213bf4a6c3a8ce",
    #   "sha256": "1aa82745c605b173550fa5c7d5b74909e3fd7f7bfad5e06c4d8a047d06fd40d6"
    # }
    # Finds the target version and returns it as below:
    # {
    #   "relpath": "/el/6/x86_64/chef-10.14.0-1.el6.x86_64.rpm",
    #   "md5": "5c8a8977f69af9c25a213bf4a6c3a8ce",
    #   "sha256": "1aa82745c605b173550fa5c7d5b74909e3fd7f7bfad5e06c4d8a047d06fd40d6",
    #   "version": "10.14.0"
    # }
    # Notice the extra "version" field that does not include the iteration number.
    def find_target_version_in(raw_version_metadata)
      available_versions = { }

      raw_version_metadata.each do |raw_version, version_info|
        version = Opscode::Version.parse(raw_version)

        # save this version only if the version string is parsable
        available_versions[version] = version_info unless version.nil?
      end

      # We send a list of versions to the Opscode::Version and use it to
      # select the version that matches the criteria.
      found_version = Opscode::Version.find_target_version(
        available_versions.keys,
        target_version,
        true,
      )

      if found_version
        available_versions[found_version].merge("version" => found_version.to_semver)
      else
        nil
      end
    end

    # HELPERS

    # Translates the given version_string into an Opscode::Version.
    # Sets the version to nil if we are looking for the :latest version.
    def parse_version_string(version_string)
      if version_string.nil? || version_string.empty? || version_string.to_s == "latest"
        nil
      else
        v = Opscode::Version.parse(version_string)
        raise InvalidDownloadPath, "Unsupported version format '#{version_string}'" if v.nil?
        v
      end
    end

    # Create a PlatformVersion object from the given strings.
    def find_platform_version(platform_string, platform_version_string)
      begin
        dsl.new_platform_version(platform_string, platform_version_string)
      rescue
        raise InvalidPlatform, "Platform information not found for #{platform_string}, #{platform_version_string}"
      end
    end
  end
end
