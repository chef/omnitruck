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

require 'fileutils'

module OmnitruckVerifier
  class MetadataCache


    @cache_dir = "~/.omnibus-verify"

    def self.cache_dir=(new_cache_dir)
      @cache_dir = new_cache_dir
    end

    def self.cache_dir
      File.expand_path(@cache_dir)
    end

    def self.metadata_cache
      File.expand_path("release_metadata", cache_dir)
    end

    # Ensure top-level cache dir is created
    def self.ensure_created
      FileUtils.mkdir_p(metadata_cache)
    end

    attr_reader :version
    attr_reader :project

    def initialize(project, version)
      @project = project
      @version = version
    end

    def store
      FileUtils.mkdir_p(metadata_dir) unless File.directory?(metadata_dir)
      yield self
    rescue Exception
      FileUtils.rm_rf(metadata_dir)
      raise
    end

    def metadata_dir
      File.join(self.class.metadata_cache, project, version)
    end

    def already_cached?
      File.exist?(metadata_file)
    end

    def metadata_file
      File.join(metadata_dir, "metadata.json")
    end

    def md5_file
      File.join(metadata_dir, "md5")
    end

    def sha256_file
      File.join(metadata_dir, "sha256")
    end

    def sha512_file
      File.join(metadata_dir, "sha512")
    end

    def cached_md5
      IO.read(md5_file).strip
    end

    def has_version?(version)
      FileUtils.mkdir(metadata_dir) unless File.directory?(metadata_dir)
    end
  end
end
