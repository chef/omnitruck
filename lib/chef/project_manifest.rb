require 'yajl'
require "mixlib/install/options"
require "mixlib/install/backend/artifactory"
require "mixlib/install/product"

require "benchmark"
class Chef
  class ProjectManifest
    attr_reader :project_name
    attr_reader :channel_name
    attr_reader :manifest

    def initialize(project_name, channel_name)
      @project_name = project_name
      @channel_name = channel_name
      @manifest = {}
    end

    #
    # Constructs a build manifest for given product & channel from artifactory.
    #
    # @return [void]
    #
    def generate
      generate_manifest
      fix_windows_manifest
    end

    #
    # This method ensures that windows manifest is generated correctly.
    # There are several historical things we are handling here. See the
    # inline comments for more details
    #
    # @return [void]
    #
    def fix_windows_manifest
      return manifest if manifest['windows'].nil?

      builds_32bit = {}
      builds_64bit = {}

      manifest['windows'].each do |platform_version, build_data|
        build_data.each do |architecture, builds|
          builds.each do |version, build|
            case architecture
            when 'x86_64'
              if %w{chef angrychef}.include?(project_name)
                # In the beginning (Chef 10) there was only 1 Chef package
                # architecture, and it was 32 bit. However, it was always stored
                # under the x86_64 manifest architecture and it was returned for
                # both x86_64 and i386 requests (1 package was used for both 32
                # and 64 bit Windows machines). This continued until Chef 12.4.2
                # - this was the first package to be stored under the i386
                # manifest architecture. There was still only 1 package and it
                # was 32 bit, but now it had the correct manifest architecture.
                # Starting with Chef 12.7 we started building 2 packages for Chef
                # - a 32 bit package for i386 architecture and a 64 bit package
                # for x86_64 architecture.
                #
                # Until Chef reaches version 12.9 we want to continue servering
                # all stable channel requests _only_ with the 32 bit package,
                # regardless of whether the user specifies x86_64 or i386
                # architecture. Once Chef 12.9 is released we will start returning
                # the correct package based upon requested architecture but only
                # for version 12.9+
                if Opscode::Version.parse(version) >= Opscode::Version.parse("12.7.0")
                  builds_64bit[version] = build
                else
                  builds_32bit[version] ||= build
                end
              elsif project_name == 'chefdk'
                # ChefDK is still only built to produce a 32-bit package. But like Chef,
                # it works on both 32-bit systems and 64-bit systems. It also may
                # sometimes be tagged as x86_64 or i386. But we want to use each
                # package for all customer architectures.
                builds_32bit[version] = build
                builds_64bit[version] = build
              else
                builds_64bit[version] = build
              end
            when 'i386', 'i686'
              builds_32bit[version] = build
              if project_name == 'chefdk'
                builds_64bit[version] = build
              end
            else
              raise "Unknown Windows architecture '#{architecture}'"
            end
          end
        end
      end

      manifest['windows'] = {
        '2008r2' => {
          'i386'   => builds_32bit,
          'x86_64' => builds_64bit
        }
      }

      manifest
    end

    #
    # This method generates a project manifest using info from Artifactory.
    #
    # @return [ProjectManifest]
    #
    def generate_manifest
      available_versions.each do |version|
        puts "Processing #{project_name} - #{channel_name} - #{version}"

        Array(artifacts_for(version)).each do |artifact|
          p = artifact.platform
          pv = artifact.platform_version
          m = artifact.architecture

          manifest[p] ||= {}
          manifest[p][pv] ||= {}
          manifest[p][pv][m] ||= {}
          manifest[p][pv][m][artifact.version] = {
            sha1: artifact.sha1,
            sha256: artifact.sha256,
            url: artifact.url
          }
        end
      end

      manifest
    end

    #
    # Returns list of available versions for a given project & channel
    #
    # @return [Array[String]]
    #   List of available versions
    def available_versions
      versions = [ ]
      PRODUCT_MATRIX.lookup(project_name).known_omnibus_projects.each do |project|
        begin
          data = artifactory_backend.get("/api/search/versions?g=com.getchef&a=#{project}&repos=omnibus-#{channel_name}-local")
        rescue Artifactory::Error::HTTPError => e
          # Artifactory returns 404 when there is no available versions for a
          # given product & channel
          if e.code == "404" || e.message =~ /404/
            puts "No available versions for '#{project_name}' - '#{channel_name}'"
            break
          else
            raise e
          end
        end

        versions << data.collect { |d| d["version"] }
      end

      versions.flatten
    end

    #
    # Returns artifacts for a given project, channel and version
    #
    # @param [String] version
    #
    # @return [Array<Mixlib::Install::ArtifactInfo>]
    #   List of information for available artifacts
    def artifacts_for(version)
      artifactory_backend(version).info
    end

    #
    # Returns a Mixlib::Install::Backend::Artifactory instance which can be used
    # to make calls to Artifactory for a given project, channel and version
    #
    # @param [String] version
    #
    # @return [Mixlib::Install::Backend::Artifactory]
    #
    def artifactory_backend(version = nil)
      opt = {
        product_name: project_name,
        channel: channel_name.to_sym
      }.tap do |c|
        c[:product_version] = version if version
      end

      options = Mixlib::Install::Options.new(opt)
      Mixlib::Install::Backend::Artifactory.new(options)
    end

    #
    # Serializes the build manifest using Yajl.
    #
    # @return [String]
    #
    def serialize
      data = manifest.dup
      data[:run_data] = {
        timestamp: Time.now.to_s
      }
      Yajl::Encoder.encode(data, nil, pretty: true)
    end
  end
end
