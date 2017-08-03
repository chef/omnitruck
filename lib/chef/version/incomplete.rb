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

require 'mixlib/versioning'

module Opscode
  class Version
    class Incomplete < Mixlib::Versioning::Format

      # SUPPORTED FORMATS:
      #
      #    MAJOR.MINOR
      #    MAJOR
      #
      # EXAMPLES:
      #
      #    10.30
      #    10
      #
      OPSCODE_INCOMPLETE_REGEX = /^(\d+)(?:\.(\d+)|)$/

      def initialize(version)
        match = version.match(OPSCODE_INCOMPLETE_REGEX)
        raise Mixlib::Versioning::ParseError, "'#{version}' is not a valid Opscode Incomplete version string!" unless match

        @input = version

        @major, @minor = match[1..2]
        @major = @major.to_i
        @minor = @minor.to_i unless @minor.nil?
        @patch = @patch.to_i unless @patch.nil?

        @prerelease = nil
        @build = nil
      end

      def to_s
        @input
      end

    end
  end
end
