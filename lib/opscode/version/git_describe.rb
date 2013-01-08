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
