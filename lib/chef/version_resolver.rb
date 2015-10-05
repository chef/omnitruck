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

    attr_reader :version
    attr_reader :build_map
    attr_reader :platform_version
    attr_reader :machine_architecture
    attr_reader :friendly_error_msg
    attr_reader :dsl

    def initialize(version_string, build_map, platform_string: nil, platform_version_string: nil, machine_string: nil)
      @dsl = PlatformDSL.new()
      dsl.from_file("platforms.rb")
      @build_map = build_map
      @version = parse_version_string(version_string)
      @friendly_error_msg = "No installer for platform #{platform_string}, platform_version #{platform_version_string}, machine #{machine_string}"
      @platform_version = find_platform_version(platform_string, platform_version_string)
      @machine_architecture = machine_string
    end

    def package_info
      available_versions = find_available_versions

      # We send a list of versions to the Opscode::Version and use it to
      # select the version that matches the criteria.
      target_version = Opscode::Version.find_target_version(
        available_versions.keys,
        version,
        true,
      )

      unless target_version
        raise InvalidDownloadPath, "Cannot find a valid chef version that matches version constraints: #{friendly_error_msg}"
      end

      # add "version" field to the package_info
      available_versions[target_version].merge("version" => target_version.to_semver)
    end

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

    # Finds all the available distro versions available from the build map
    def find_available_distro_versions
      # omnitruck has some core platforms like ubuntu, windows, ...
      # and some secondary platforms that map onto core platforms like linuxmint, scientific
      # mapped_name will return the original name if it is not mapped
      core_platform = platform_version.mapped_name

      # first make sure we have some builds available for the given platform
      if !build_map[core_platform]
        raise InvalidDownloadPath, "Cannot find any chef versions for core platform #{core_platform}: #{friendly_error_msg}"
      end

      # get all the available distro versions
      distro_versions_available = build_map[core_platform].keys

      # select only the packages from the distro versions that are <= the version we are looking for
      # we do not want to select el7 packages for el6 platform
      distro_versions_available.select! {|v| dsl.new_platform_version(core_platform, v) <= platform_version }

      if distro_versions_available.length == 0
        raise InvalidDownloadPath, "Cannot find any available chef versions for this platform version #{platform_version.mapped_name} #{platform_version.mapped_version}: #{friendly_error_msg}"
      end

      # sort the available distro versions from earlier to later: 10.04 then 10.10 etc.
      distro_versions_available.sort! {|v1,v2| dsl.new_platform_version(core_platform, v1) <=> dsl.new_platform_version(core_platform, v2) }

      # Return the sorted distro versions with their package information
      distro_versions_available.map do |version|
        build_map[core_platform][version]
      end
    end

    # Walks through all matching distro versions and collects the available versions
    # in a hash indexed by the version itself.
    def find_available_versions
      available_versions = { }

      find_available_distro_versions.each do |distro_version|
        # if the machine architecture does not map, do not collect any versions
        # from this distro_version.
        next if distro_version[machine_architecture].nil?

        distro_version[machine_architecture].each do |raw_version, version_info|
          version = Opscode::Version.parse(raw_version)

          # save this version only if the version string is parsable
          available_versions[version] = version_info unless version.nil?
        end
      end

      available_versions
    end

  end
end
