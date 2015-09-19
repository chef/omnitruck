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
require 'opscode/version/incomplete'
require 'forwardable'

module Opscode
  class Version
    SUPPORTED_FORMATS = Mixlib::Versioning::DEFAULT_FORMATS + [
      Opscode::Version::Incomplete
    ]
    extend Forwardable

    include Comparable

    delegate [:major,
              :minor,
              :patch,
              :prerelease,
              :build,
              :release?,
              :release_nightly?,
              :prerelease?,
              :prerelease_nightly?,
              :input,
              :in_same_prerelease_line?,
              :to_semver_string,
    ] => :mixlib_version

    attr_reader :iteration
    attr_reader :mixlib_version

    def initialize(version, iteration)
      @mixlib_version = version
      @iteration = iteration.to_i unless iteration.nil?
    end

    # Returns +true+ if +other+ and this +Version+ share the same
    # major, minor, and patch values.  Prerelease and build specifiers
    # are not taken into consideration.
    def in_same_release_line?(other)
      major == other.major &&
        # minor and patch always match if one or the other is nil (~>-like behavior)
        ( minor.nil? || other.minor.nil? || minor == other.minor ) &&
        ( patch.nil? || other.patch.nil? || patch == other.patch )
    end

    def to_s
      if iteration.nil?
        input
      else
        "#{input}-#{iteration}"
      end
    end

    def <=>(other)

      # First, perform comparisons based on major, minor, and patch
      # versions.  These are always presnt and always non-nil
      cmp = mixlib_version <=> other.mixlib_version
      return cmp unless cmp == 0

      # Some older version formats improperly include a package iteration in
      # the version string. This is different than a build specifier and
      # valid release versions may include an iteration. We'll transparently
      # handle this case and compare iterations if it was parsed by the
      # implementation class.
      if iteration.nil? && other.iteration
        return -1
      elsif iteration && other.iteration.nil?
        return 1
      elsif iteration && other.iteration
        return iteration <=> other.iteration
      end

      # If we get down here, they're both equal
      return 0
    end

    def eql?(other)
      mixlib_version.eql?(other) &&
        iteration == other.iteration
    end

    def hash
      [major, minor, patch, prerelease, build].compact.join(".").hash
    end

    ###########################################################################

    ###########################################################################
    # Class Methods
    ###########################################################################

    # Select the most recent version from +all_versions+ that satisfies
    # the filtering constraints provided by +filter_version+ and +allow_all+.
    #
    # +all_versions+ is an array of +Opscode::Version+ objects.  This is
    # the "world" of versions we will be filtering to produce the final
    # target version.
    #
    # +allow_all+ determines if we include the whole world in what we return
    # or if we only return releases.
    #
    # +filter_version+ is a +Opscode::Version+ (or nil) that provides more
    # fine-grained filtering.
    #
    # If +filter_version+ specifies a release (e.g. 1.0.0), then the
    # target version that is returned will be in the same "release line"
    # (it will have the same major, minor, and patch versions).
    #
    # If +filter_version+ specifies a pre-release (e.g.,
    # 1.0.0-alpha.1), the returned target version will be in the same
    # "pre-release line", and will also include any nightly builds.
    #
    # If +filter_version+ specifies a nightly build version (whether it
    # is a pre-release or not), no filtering is performed at all, and
    # +filter_version+ *is* the target version
    #
    # If +filter_version+ is +nil+, then only +allow_all+ is used for
    # filtering.
    #
    # In all cases, the returned +Opscode::Version+ is the most recent
    # one in +all_versions+ that satisfies the given constraints.
    def self.find_target_version(all_versions, filter_version, allow_all)
      if filter_version && filter_version.build
        # If we've requested a nightly (whether for a pre-release or release),
        # there's no sense doing any other filtering; just return that version
        filter_version
      elsif filter_version && filter_version.prerelease
        # If we've requested a prerelease, include the latest nightlies on that
        # prerelease as well.
        all_versions.select{|v| v.in_same_prerelease_line?(filter_version)}.max
      else
        # If we've gotten this far, we're either just interested in
        # variations on a specific release, or the latest of all versions
        # (depending on various combinations of prerelease and nightly
        # status)
        all_versions.select do |v|
          # If we're given a version to filter by, then we're only
          # interested in other versions that share the same major, minor,
          # and patch versions.
          #
          # If we weren't given a version to filter by, then we don't
          # care, and we'll take everything
          in_release_line = if filter_version
                              filter_version.in_same_release_line?(v)
                            else
                              true
                            end

          in_release_line && (allow_all || v.release?)
        end.max
      end
    end

    def self.parse(version_str)
      # Mixlib::Versioning thinks the iterations at the end of
      # our semvered omnibus package names are prereleases.
      # This class will take responsibility of managing the iteration.
      match = version_str.match /(.*)-(\d*)\z/
      if match.nil?
        version = Mixlib::Versioning.parse(version_str, SUPPORTED_FORMATS)
        Opscode::Version.new(version, nil) if version
      else
        version = Mixlib::Versioning.parse(match[1], SUPPORTED_FORMATS)
        Opscode::Version.new(version, match[2]) if version
      end
    end
  end
end
