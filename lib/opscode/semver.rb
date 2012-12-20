module Opscode
  class SemVer
    include Comparable

    SEMVER_REGEX = /^(\d+)\.(\d+)\.(\d+)(?:\-([\dA-Za-z\-\.]+))?(?:\+([\dA-Za-z\-\.]+))?$/

    attr_reader :major, :minor, :patch, :prerelease, :build

    def initialize(version)
      match = version.match(SEMVER_REGEX)
      if match
        @major, @minor, @patch, @prerelease, @build = match[1..5]

        @major, @minor, @patch = [@major, @minor, @patch].map(&:to_i)

        @prerelease = nil if (@prerelease.nil? || @prerelease.empty?)
        @build = nil if (@build.nil? || @build.empty?)
      else
        raise ArgumentError, "'#{version}' is not a valid semver version string!"
      end
    end

    def prerelease?
      !!@prerelease
    end

    def nightly?
      !!@build
    end

    def release?
      @prerelease.nil? && @build.nil?
    end

    def in_same_release_tree(other)
      raise(ArgumentError, "Must compare with SemVer")unless other.is_a?(SemVer)
      @major == other.major && @minor == other.minor && @patch == other.patch
    end

    def to_s
      v = [@major, @minor, @patch].join(".")
      v += "-#{@prerelease}" if @prerelease
      v += "+#{@build}" if @build
      v
    end
    
    def <=>(other)
      raise(ArgumentError, "Must compare with SemVer") unless other.is_a?(SemVer)

      maj = @major <=> other.major
      return maj unless maj == 0

      min = @minor <=> other.minor
      return min unless min == 0

      pat = @patch <=> other.patch
      return pat unless pat == 0

      if @prerelease.nil? && !other.prerelease.nil?
        return 1 # pre-releases come before releases
      elsif !@prerelease.nil? && other.prerelease.nil?
        return -1
      elsif @prerelease.nil? && other.prerelease.nil?
        # Continue on; no need to do a comparison
      else
        pre = compare_dot_components(@prerelease, other.prerelease)
        return pre unless pre == 0
      end

      if @build.nil? && !other.build.nil?
        return -1 # empty build info comes before build info
      elsif !@build.nil? && other.build.nil?
        return 1
      elsif @build.nil? && other.build.nil?
        # Continue on; no need to do a comparison
      else
        build_ver = compare_dot_components(@build, other.build)
        return build_ver unless build_ver == 0
      end

      0
    end
    
    def eql?(other)
      raise(ArgumentError, "Must compare with SemVer") unless other.is_a?(SemVer)

      @major == other.major &&
        @minor == other.minor &&
        @patch == other.patch &&
        @prerelease == other.prerelease &&
        @build == other.build
    end

    def hash
      to_s.hash
    end

    ################################################################################

    private

    def maybe_int(n)
      Integer(n)
    rescue
      n
    end
    
    # +a+ and +b+ are both taken to be strings
    def compare_dot_components(a_item, b_item)

      a_components = a_item.split(".")
      b_components = b_item.split(".")
      
      max_length = [a_components.length, b_components.length].max
      
      (0..(max_length-1)).each do |i|
        a = maybe_int(a_components[i])
        b = maybe_int(b_components[i])
        
        if a.nil? && !b.nil?
          return -1
        elsif !a.nil? && b.nil?
          return 1
        elsif a.nil? && b.nil?
          return 0
        end
        
        # If both are the same type, compare 
        if (a.is_a?(Integer) && b.is_a?(Integer)) || (a.is_a?(String) && b.is_a?(String))
          comp = a <=> b
          return comp unless comp == 0
        end
        
        # numeric identifiers have lower precedence, so if the two
        # pieces don't match, we can cut short the entire comparison
        # right now
        if a.is_a?(Integer) && b.is_a?(String)
          return -1 # B was "bigger", since numeric identifiers have lower precedence 
        end
        
        if a.is_a?(String) && b.is_a?(Integer)
          return 1
        end
      end
      
      # if we get down here, they're totally the same
      return 0
    end

  end
end
