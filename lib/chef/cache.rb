#
# Copyright:: Copyright (c) 2016 Chef Software, Inc.
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

require "fileutils"
require "chef/project_manifest"

class Chef
  class Cache
    class MissingManifestFile < StandardError; end

    KNOWN_PROJECTS = %w(
      angrychef
      angry-omnibus-toolchain
      chef
      chef-server
      chefdk
      delivery-cli
      omnibus-toolchain
      push-jobs-client
    )

    KNOWN_CHANNELS = %w(
      current
      stable
    )

    attr_reader :metadata_dir

    #
    # Initializer for the cache.
    #
    # @param [String] metadata_dir
    #   the directory which will be used to create files in & read files from.
    #
    def initialize(metadata_dir = "./metadata_dir")
      @metadata_dir = metadata_dir

      KNOWN_CHANNELS.each do |channel|
        FileUtils.mkdir_p(File.join(metadata_dir, channel))
      end
    end

    #
    # Updates the cache
    #
    # @return [void]
    #
    def update
      KNOWN_PROJECTS.each do |project|
        KNOWN_CHANNELS.each do |channel|
          manifest = ProjectManifest.new(project, channel)
          manifest.generate

          File.open(project_manifest_path(project, channel), "w") do |f|
            f.puts manifest.serialize
          end
        end
      end
    end

    #
    # Returns the file path for the manifest file that belongs to the given
    # project & channel.
    #
    # @parameter [String] project
    # @parameter [String] channel
    #
    # @return [String]
    #   File path of the manifest file.
    #
    def project_manifest_path(project, channel)
      File.join(metadata_dir, channel, "#{project}-manifest.json")
    end

    #
    # Returns the manifest for a given project and channel from the cache.
    #
    # @parameter [String] project
    # @parameter [String] channel
    #
    # @return
    #   [Hash] contents of the manifest file
    #
    def manifest_for(project, channel)
      manifest_path = project_manifest_path(project, channel)

      if File.exist?(manifest_path)
        JSON.parse(File.read(manifest_path))
      else
        raise MissingManifestFile, "Can not find the manifest file for '#{project}' - '#{channel}'"
      end
    end

    #
    # Returns the last updated time of the manifest for a given project and channel.
    #
    # @parameter [String] project
    # @parameter [String] channel
    #
    # @return
    #   [String] timestamp for the last modified time.
    #
    def last_modified_for(project, channel)
      manifest_path = project_manifest_path(project, channel)

      if File.exist?(manifest_path)
        manifest = JSON.parse(File.read(manifest_path))
        manifest["run_data"]["timestamp"]
      else
        raise MissingManifestFile, "Can not find the manifest file for '#{project}' - '#{channel}'"
      end
    end

  end
end
