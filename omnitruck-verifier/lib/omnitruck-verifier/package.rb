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

require 'omnitruck-verifier/bucket_lister'

module OmnitruckVerifier
  class Package < Struct.new(:key, :md5)

    PUBLISHED_PKG_BUCKET = "opscode-omnibus-packages".freeze

    def self.all_by_relpath
      packages_by_relpath = {}
      BucketLister.new(PUBLISHED_PKG_BUCKET).fetch do |key, md5|
        maybe_package = new(key, md5)
        packages_by_relpath[maybe_package.relpath] = maybe_package if maybe_package.valid_pkg_name?
      end
      packages_by_relpath
    end

    attr_accessor :expected_md5

    # relpath in the metadata files starts with a "/"
    def relpath
      "/#{key}"
    end

    def valid_pkg_name?
      key !~ /^logs/ and key != "README.md" and key !~ /test.*txt/ and key !~ /chef.*platform\-support/
    end

    def valid_md5?
      expected_md5 == md5
    end

    def explain_error
      <<-E
metadata of #{relpath} doesn't match.
  expected MD5 (cached metadata): #{expected_md5}
  actual MD5 (from AWS): #{md5}
E
    end

  end
end
