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

require 'digest'
require 'yajl'

METADATA_BUCKET = "opscode-omnibus-package-metadata"
RELEASE_REGEX = %r[(.+)\-release\-manifest\/(.+).json]

SKIP_FILES = %r[chef\-.*platform\-names\.json]

module OmnitruckVerifier
  class MetadataFile
    def self.all
      files = []
      BucketLister.new(METADATA_BUCKET).fetch do |key, md5|
        next if key =~ SKIP_FILES
        files << from_s3_key(key, md5)
      end
      files
    end

    def self.from_s3_key(key, md5)
      if matches = RELEASE_REGEX.match(key)
        project, version = matches[1], matches[2]
        url = "https://#{METADATA_BUCKET}.s3.amazonaws.com/#{key}"
        new(url, project, version, md5)
      else
        raise "Bad metadata file: #{key} #{md5}"
      end
    end

    attr_reader :url
    attr_reader :project
    attr_reader :version
    attr_reader :remote_md5
    attr_reader :cache

    def initialize(url, project, version, remote_md5)
      @url = url.gsub("+", "%2b")
      @project = project
      @version = version
      @remote_md5 = remote_md5
    end

    def cache
      @cache ||= MetadataCache.new(project, version)
    end

    def cached?
      cache.already_cached?
    end

    def cached_md5
      cache.cached_md5
    end

    def cached_metadata
      cache.metadata_file
    end

    def fetch
      cache.store do |c|
        File.open(cached_metadata, "w+") do |f|
          f.print(download_metadata)
        end
        File.open(c.md5_file, "w+") { |f| f.print("#{md5}\n") }
        File.open(c.sha256_file, "w+") { |f| f.print("#{sha256}\n") }
        File.open(c.sha512_file, "w+") { |f| f.print("#{sha512}\n") }
      end
    end

    def download_metadata
      RestClient.get(url)
    rescue Exception
      $stderr.puts "Error fetching #{url}"
      raise
    end

    def package_checksums
      manifest = Yajl::Parser.parse(IO.read(cached_metadata))
      checksum_data = []
      manifest.each_value do |md_by_platform|
        md_by_platform.each_value do |md_by_platform_version|
          md_by_platform_version.each_value do |md_by_release|
            # only one release per metadata file
            checksum_data << md_by_release.values.first
          end
        end
      end
      checksum_data
    end

    # Does a quick check that the metadata file hasn't been tampered with by
    # checking the md5 from amazon against what we have cached. MD5 isn't
    # especially strong nowadays, so we need supplement this with SHA2 based
    # verification; however, S3 gives you the md5 of a file for free.
    def quick_verify
      cached_md5 == remote_md5 and remote_md5 == md5
    end

    class InvalidPackage < StandardError
    end

    # Like quick_verify but raises if the checksum doesn't match
    def quick_verify!
      quick_verify or raise InvalidPackage, explain_error
    end

    def explain_error
      <<-E
md5 of #{cached_metadata} doesn't match.
  AWS:            #{remote_md5}
  Cached MD5:     #{cached_md5}
  Recomputed MD5: #{md5}
E
    end

    def md5
      @md5 ||= digest(Digest::MD5)
    end

    def sha256
      @sha256 ||= digest(Digest::SHA256)
    end

    def sha512
      @sha512 ||= digest(Digest::SHA512)
    end

    private

    def digest(digest_class)
      digest = digest_class.new
      File.open(cached_metadata) do |io|
        while chunk = io.read(1024 * 8)
          digest.update(chunk)
        end
      end
      digest.hexdigest
    end

  end
end

