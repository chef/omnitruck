module Opscode
  module Versions
    class GitDescribeVersion < Version

      # This class is basically to handle the handful of variations we
      # currently have in Omnitruck that are based on 'git describe'
      # output.  It is not intended to be fully general.  For example,
      # the pre-releases we do have are only 'alpha's at this time, so
      # that's all the regexes handle.
      #
      # As coded, this class is not for long-term use, but rather as a
      # stop-gap measure until we fully transition over to proper SemVer
      # versioning.

      # 10.16.2-49-g21353f0-1
      OPSCODE_GIT_DESCRIBE_REGEX_1 = /^(\d+)\.(\d+)\.(\d+)\-(\d+)\-g([a-g0-9]{7})\-(\d+)$/

      # 11.0.0-alpha-10-g642ffed
      OPSCODE_GIT_DESCRIBE_REGEX_2 = /^(\d+)\.(\d+)\.(\d+)\-(alpha)\-(\d+)\-g([a-g0-9]{7})$/

      # 11.0.0-alpha.1-1-gcea071e
      OPSCODE_GIT_DESCRIBE_REGEX_3 =  /^(\d+)\.(\d+)\.(\d+)\-(alpha\.\d+)\-(\d+)\-g([a-g0-9]{7})$/

      attr_reader :commits_since, :commit_sha, :iteration

      def initialize(version)

        # Try each variation in turn; if none of them work, bail out.
        #
        # Each initialization method takes responsibility for parsing
        # the input and setting instance variables as appropriate for
        # each versioning scheme.
        success = initialize_1(version) || initialize_2_3(version)
        
        unless success
          raise ArgumentError, "'#{version}' is not a valid Opscode 'git-describe' version string!"
        end
        
        # We succeeded, so stash the original input away for later
        @input = version
      end

      def to_s
        @input
      end

      private

      def initialize_1(version)
        match = version.match(OPSCODE_GIT_DESCRIBE_REGEX_1)
        return nil unless match
        
        @major, @minor, @patch, @commits_since, @commit_sha, @iteration = match[1..6]
        @major, @minor, @patch, @commits_since, @iteration = [@major, @minor, @patch, @commits_since, @iteration].map(&:to_i)
        
        @prerelease = nil
        
        # Our comparison logic is built around SemVer semantics, so
        # we'll store our internal information in that format
        @build = "#{@commits_since}.g#{@commit_sha}.#{@iteration}"
        
        true
      end

      def initialize_2_3(version)
        match = version.match(OPSCODE_GIT_DESCRIBE_REGEX_2) || version.match(OPSCODE_GIT_DESCRIBE_REGEX_3)

        return nil unless match
        
        @major, @minor, @patch, @prerelease, @commits_since, @commit_sha = match[1..6]
        @major, @minor, @patch, @commits_since = [@major, @minor, @patch, @commits_since].map(&:to_i)

        @build = "#{@commits_since}.g#{@commit_sha}"
        
        true
      end

    end
  end
end
