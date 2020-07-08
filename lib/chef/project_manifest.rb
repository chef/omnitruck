require 'yajl'
require "mixlib/install"
require "mixlib/install/dist"
require "mixlib/install/options"
require "mixlib/install/backend/package_router"
require 'chef/version'
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
    # Constructs a build manifest for given product & channel from package router.
    #
    # @return [void]
    #
    def generate
      generate_manifest
    end

    #
    # This method generates a project manifest using info from packages.chef.io
    #
    # @return [ProjectManifest]
    #
    def generate_manifest
      available_versions.each do |version|
        puts "Processing #{project_name} - #{channel_name} - #{version}"

        artifacts_for(version).each do |artifact|
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
      Mixlib::Install.new(
        product_name: project_name,
        channel: channel_name.to_sym,
        user_agent_headers: ['omnitruck']
      ).available_versions
    rescue Mixlib::Install::Backend::ArtifactsNotFound
      # Return an empty array if no artifacts are found
      []
    end

    #
    # Returns artifacts for a given project, channel and version
    #
    # @param [String] version
    #
    # @return [Array<Mixlib::Install::ArtifactInfo>]
    #   List of information for available artifacts
    def artifacts_for(version)
      artifacts = Mixlib::Install.new(
        product_name: project_name,
        channel: channel_name.to_sym,
        product_version: version,
        user_agent_headers: ['omnitruck']
      ).artifact_info

      Array(artifacts)
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
