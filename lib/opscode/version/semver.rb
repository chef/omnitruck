module Opscode
  class Version
    class SemVer < Version

      # Format that implements SemVer 2.0.0-rc.1 (http://semver.org/)
      #
      # SUPPORTED FORMATS:
      #
      #    MAJOR.MINOR.PATCH
      #    MAJOR.MINOR.PATCH-PRERELEASE
      #    MAJOR.MINOR.PATCH-PRERELEASE+BUILD
      #
      # EXAMPLES:
      #
      #    11.0.0
      #    11.0.0-alpha.1
      #    11.0.0-alpha1+20121218164140
      #    11.0.0-alpha1+20121218164140.git.207.694b062
      #
      SEMVER_REGEX = /^(\d+)\.(\d+)\.(\d+)(?:\-([\dA-Za-z\-\.]+))?(?:\+([\dA-Za-z\-\.]+))?$/

      def initialize(version)
        match = version.match(SEMVER_REGEX)
        raise ArgumentError, "'#{version}' is not a valid semver version string!" unless match

        @input = version

        @major, @minor, @patch, @prerelease, @build = match[1..5]
        @major, @minor, @patch = [@major, @minor, @patch].map(&:to_i)

        @prerelease = nil if (@prerelease.nil? || @prerelease.empty?)
        @build = nil if (@build.nil? || @build.empty?)
      end

      def to_s
        @input
      end

    end
  end
end
