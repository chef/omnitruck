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

# -*- coding: UTF-8 -*-

require 'restclient'
require 'nokogiri'
require 'uri'

module OmnitruckVerifier

  # == BucketLister
  # List some S3 buckets. There are plenty of other S3 tools out there but we
  # NIH'd it up because none of them worked correctly for this use case. Other
  # ruby tools are either a royal PITA (aws/s3), completely fail when you don't
  # provide valid credentials (uber-s3), or use eventmachine (too big a
  # hammer). `s3cmd` doesn't seem to let you disable the separator thing that
  # makes S3 look like a filesystem (e.g, `s3cmd ls` only returns one level of
  # "directories", and we have object keys like
  # distro/distro_version/arch/package). For our use case, we only interact
  # with public buckets, and we'd rather make fewer S3 requests and not
  # traverse a hierarchy.
  #
  # === Usage
  #   BucketLister.new("poop-bucket").new.fetch do |key, md5|
  #     puts "obj key: " + key
  #     puts "obj md5: " + md5
  #   end
  class BucketLister

    KEY = "Key".freeze
    ETAG = "ETag".freeze

    attr_reader :bucket_name

    def initialize(bucket_name)
      @bucket_name = bucket_name
    end

    def fetch
      marker, truncated = "", true

      while truncated
        truncated, contents = fetch_next(marker)
        contents.each do |item|
          marker = key_of(item)
          yield key_of(item), etag_of(item)
        end
      end
    end

    private

    def key_of(element)
      element.xpath(KEY).text
    end

    def etag_of(element)
      element.xpath(ETAG).text.gsub('"', '')
    end

    def fetch_next(from_marker)
      marker = escape_marker(from_marker)
      raw = RestClient.get("https://#{bucket_name}.s3.amazonaws.com/?marker=#{marker}&max-keys=500")
      doc = Nokogiri::XML.parse(raw)
      doc.remove_namespaces! #  (╯°□°）╯︵ ┻━┻

      truncated = doc.xpath('//ListBucketResult/IsTruncated').first.text == "true"
      contents = doc.xpath('//ListBucketResult/Contents')
      [truncated, contents]
    end

    # URI escape a key so we can pass it as a query parameter to S3.  S3
    # doesn't like "+" character in path part of URL even though it's legal, so
    # we have to hack around that.
    def escape_marker(marker)
      marker = URI.escape(marker)
      marker.gsub("+", "%2b")
    end
  end
end
