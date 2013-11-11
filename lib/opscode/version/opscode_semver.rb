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

module Opscode
  class Version
    # Defines the format of the semantic version scheme used for Opscode
    # projects.  They are SemVer-2.0.0-rc.1 compliant, but we further
    # constrain the allowable strings for prerelease and build
    # signifiers for our own internal standards.
    class OpscodeSemVer < SemVer

      # The pattern is: YYYYMMDDHHMMSS.git.COMMITS_SINCE.SHA1
      OPSCODE_BUILD_REGEX = /^\d{14}\.git\.\d+\.[a-f0-9]{7}$/

      # Allows the following:
      #
      # alpha, alpha.1, alpha.2, etc.
      # beta, beta.1, beta.2, etc.
      # rc, rc.1, rc.2, etc.
      #
      # TODO: Should we allow bare prerelease tags like "alpha", "beta", and "rc", without a number?
      # TODO: Should we allow "zero tags", like "alpha.0"?
      OPSCODE_PRERELEASE_REGEX = /^(alpha|beta|rc)(\.\d+)?$/

      def initialize(version)
        super(version)

        unless @prerelease.nil?
          unless @prerelease.match(OPSCODE_PRERELEASE_REGEX)
            raise ArgumentError, "'#{@prerelease}' is not a valid Opscode prerelease signifier"
          end
        end

        unless @build.nil?
          unless @build.match(OPSCODE_BUILD_REGEX)
            raise ArgumentError, "'#{@build}' is not a valid Opscode build signifier"
          end
        end
      end

    end
  end
end
