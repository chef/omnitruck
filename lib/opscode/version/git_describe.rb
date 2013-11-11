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
    class GitDescribe < Version

      # This class is basically to handle the handful of variations we
      # currently have in Omnitruck that are based on 'git describe'
      # output.
      #
      # SUPPORTED FORMATS:
      #
      #    MAJOR.MINOR.PATCH.PRERELEASE-COMMITS_SINCE-gGIT_SHA
      #    MAJOR.MINOR.PATCH-PRERELEASE-COMMITS_SINCE-gGIT_SHA
      #    MAJOR.MINOR.PATCH.PRERELEASE-COMMITS_SINCE-gGIT_SHA-ITERATION
      #    MAJOR.MINOR.PATCH-PRERELEASE-COMMITS_SINCE-gGIT_SHA-ITERATION
      #
      # EXAMPLES:
      #
      #    10.16.2-49-g21353f0-1
      #    10.16.2.rc.1-49-g21353f0-1
      #    11.0.0-alpha-10-g642ffed
      #    11.0.0-alpha.1-1-gcea071e
      #
      OPSCODE_GIT_DESCRIBE_REGEX = /^(\d+)\.(\d+)\.(\d+)(?:-|.)?(.+)?\-(\d+)\-g([a-g0-9]{7})(?:-|.)?(\d+)?$/

      attr_reader :commits_since, :commit_sha, :iteration

      def initialize(version)
        match = version.match(OPSCODE_GIT_DESCRIBE_REGEX)

        unless match
          raise ArgumentError, "'#{version}' is not a valid Opscode 'git-describe' version string!"
        end

        @major, @minor, @patch, @prerelease, @commits_since, @commit_sha, @iteration = match[1..7]
        @major, @minor, @patch, @commits_since, @iteration = [@major, @minor, @patch, @commits_since, @iteration].map(&:to_i)

        # Our comparison logic is built around SemVer semantics, so
        # we'll store our internal information in that format
        @build = "#{@commits_since}.g#{@commit_sha}.#{@iteration}"


        # We succeeded, so stash the original input away for later
        @input = version
      end

      def to_s
        @input
      end

    end
  end
end
