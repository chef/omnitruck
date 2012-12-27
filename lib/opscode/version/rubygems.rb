module Opscode
  class Version
    class Rubygems < Version

      OPSCODE_RUBYGEMS_REGEX = /^(\d+)\.(\d+)\.(\d+)(?:\.((?:alpha|beta|rc)\.\d+))?(?:\-(\d+))?$/

      def initialize(version)
        match = version.match(OPSCODE_RUBYGEMS_REGEX)
        raise ArgumentError, "'#{version}' is not a valid Opscode Rubygems version string!" unless match

        @input = version

        @major, @minor, @patch, @prerelease, @iteration = match[1..5]
        @major, @minor, @patch = [@major, @minor, @patch].map(&:to_i)

        # Do not convert @build to an integer; SemVer sorting logic will handle the conversion
        @prerelease = nil if (@prerelease.nil? || @prerelease.empty?)
      end

      def to_s
        @input
      end

    end
  end
end
