require 'opscode/semver'

module Opscode
  
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
