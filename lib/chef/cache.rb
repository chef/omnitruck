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

require "redis"
require "chef/project_manifest"
require "mixlib/install/dist"
require "mixlib/install/product"
require "mixlib/install/product_matrix"

class Chef
  class Cache
    class MissingManifestFile < StandardError; end

    KNOWN_PROJECTS = PRODUCT_MATRIX.products

    KNOWN_CHANNELS = %w(
      current
      stable
      unstable
    )

    attr_reader :redis

    #
    # Initializer for the cache.
    #
    # @param [String] metadata_dir
    #   the directory which will be used to create files in & read files from.
    #
    def initialize()
      # Use REDIS_URL environment variable to configure where redis is
      @redis = Redis.new
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
          @redis.set("#{channel}/#{project}", manifest.serialize)
        end
      end
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
      content = @redis.get("#{channel}/#{project}")
      unless content.nil?
        JSON.parse(content)
      else
        raise MissingManifestFile, "Can not find the manifest for '#{project}' - '#{channel}'"
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
      content = @redis.get("#{channel}/#{project}")
      unless content.nil?
        manifest = JSON.parse(content)
        manifest["run_data"]["timestamp"]
      else
        raise MissingManifestFile, "Can not find the manifest for '#{project}' - '#{channel}'"
      end
    end
  end
end
