module Opscode
  module Versions
    class SemVer < Version

      SEMVER_REGEX = /^(\d+)\.(\d+)\.(\d+)(?:\-([\dA-Za-z\-\.]+))?(?:\+([\dA-Za-z\-\.]+))?$/

      def self.as_semver_string(v)
        raise ArgumentError unless v.is_a? Version
        s = [v.major, v.minor, v.patch].join(".")
        s += "-#{v.prerelease}" if v.prerelease
        s += "+#{v.build}" if v.build
        s
      end

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
