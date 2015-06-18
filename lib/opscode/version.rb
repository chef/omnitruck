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

require 'opscode/version/semver'
require 'opscode/version/opscode_semver'
require 'opscode/version/rubygems'
require 'opscode/version/git_describe'
require 'opscode/version/incomplete'

module Opscode
  class Version

    include Comparable

    attr_reader :major, :minor, :patch, :prerelease, :build, :iteration

    def initialize(version)
      raise Error, "You must override the initializer!"
    end

    # Is this an official release?
    def release?
      @prerelease.nil? && @build.nil?
    end

    # Is this an official pre-release? (i.e., not a nightly build)
    def prerelease?
      @prerelease && @build.nil?
    end

    # Is this a nightly build of a release?
    def release_nightly?
      @prerelease.nil? && @build
    end

    # Is this a nightly build of a pre-release?
    def prerelease_nightly?
      @prerelease && @build
    end

    # Is this a nightly build (either of a release or a pre-release)?
    def nightly?
      !!@build
    end

    # Returns +true+ if +other+ and this +Version+ share the same
    # major, minor, and patch values.  Prerelease and build specifiers
    # are not taken into consideration.
    def in_same_release_line?(other)
      @major == other.major &&
        # minor and patch always match if one or the other is nil (~>-like behavior)
        ( @minor.nil? || other.minor.nil? || @minor == other.minor ) &&
        ( @patch.nil? || other.patch.nil? || @patch == other.patch )
    end

    # Returns +true+ if +other+ and this +Version+ share the same
    # major, minor, patch, and prerelease values.  Build specifiers
    # are not taken into consideration.
    def in_same_prerelease_line?(other)
      @major == other.major && @minor == other.minor && @patch == other.patch && prerelease_eql(other)
    end

    def prerelease_eql(other)
      my_prerelease = @prerelease.gsub(/-\d*\z/, '') if @prerelease
      other_prerelease = other.prerelease.gsub(/-\d*\z/, '') if other.prerelease
      my_prerelease == other_prerelease
    end

    def to_s
      raise Error, "You must override #to_s"
    end

    def to_semver_string
      s = [@major, @minor, @patch].join(".")
      s += "-#{@prerelease}" if @prerelease
      s += "+#{@build}" if @build
      s
    end

    def <=>(other)

      # First, perform comparisons based on major, minor, and patch
      # versions.  These are always presnt and always non-nil
      maj = @major <=> other.major
      return maj unless maj == 0

      min = @minor <=> other.minor
      return min unless min == 0

      pat = @patch <=> other.patch
      return pat unless pat == 0

      # Next compare pre-release specifiers.  A pre-release sorts
      # before a release (e.g. 1.0.0-alpha.1 comes before 1.0.0), so
      # we need to take nil into account in our comparison.
      #
      # If both have pre-release specifiers, we need to compare both
      # on the basis of each component of the specifiers.
      if @prerelease && other.prerelease.nil?
        return -1
      elsif @prerelease.nil? && other.prerelease
        return 1
      elsif @prerelease && other.prerelease
        pre = compare_dot_components(@prerelease, other.prerelease)
        return pre unless pre == 0
      end

      # Build specifiers are compared like pre-release specifiers,
      # except that builds sort *after* everything else
      # (e.g. 1.0.0+build.123 comes after 1.0.0, and
      # 1.0.0-alpha.1+build.123 comes after 1.0.0-alpha.1)
      if @build.nil? && other.build
        return -1
      elsif @build && other.build.nil?
        return 1
      elsif @build && other.build
        build_ver = compare_dot_components(@build, other.build)
        return build_ver unless build_ver == 0
      end

      # Some older version formats improperly include a package iteration in
      # the version string. This is different than a build specifier and
      # valid release versions may include an iteration. We'll transparently
      # handle this case and compare iterations if it was parsed by the
      # implementation class.
      if @iteration.nil? && other.iteration
        return -1
      elsif @iteration && other.iteration.nil?
        return 1
      elsif @iteration && other.iteration
        return @iteration <=> other.iteration
      end

      # If we get down here, they're both equal
      return 0
    end

    def eql?(other)
      @major == other.major &&
        @minor == other.minor &&
        @patch == other.patch &&
        @prerelease == other.prerelease &&
        @build == other.build
    end

    def hash
      [@major, @minor, @patch, @prerelease, @build].compact.join(".").hash
    end

    ###########################################################################

    private

    # If a String +n+ can be parsed as an Integer do so; otherwise, do
    # nothing.
    #
    # (+nil+ is a valid input.)
    def maybe_int(n)
      Integer(n)
    rescue
      n
    end

    # Compares prerelease and build version component strings
    # according to semver 2.0.0-rc.1 semantics.
    #
    # Returns -1, 0, or 1, just like the spaceship operator (+<=>+),
    # and is used in the implemntation of +<=>+ for this class.
    #
    # Prerelease and build specifiers are dot-separated strings.
    # Numeric components are sorted numerically; otherwise, sorting is
    # standard ASCII order.  Numerical components have a lower
    # precedence than string components.
    #
    # See http://www.semver.org for more.
    #
    # Both +a_item+ and +b_item+ should be Strings; +nil+ is not a
    # valid input.
    def compare_dot_components(a_item, b_item)
      a_components = a_item.split(".")
      b_components = b_item.split(".")

      max_length = [a_components.length, b_components.length].max

      (0..(max_length-1)).each do |i|
        # Convert the ith component into a number if possible
        a = maybe_int(a_components[i])
        b = maybe_int(b_components[i])

        # Since the components may be of differing lengths, the
        # shorter one will yield +nil+ at some point as we iterate.
        if a.nil? && !b.nil?
          # a_item was shorter
          return -1
        elsif !a.nil? && b.nil?
          # b_item was shorter
          return 1
        end

        # Now we need to compare appropriately based on type.
        #
        # Numbers have lower precedence than strings; therefore, if
        # the components are of differnt types (String vs. Integer),
        # we just return -1 for the numeric one and we're done.
        #
        # If both are the same type (Integer vs. Integer, or String
        # vs. String), we can just use the native comparison.
        #
        if a.is_a?(Integer) && b.is_a?(String)
          # a_item was "smaller"
          return -1
        elsif a.is_a?(String) && b.is_a?(Integer)
          # b_item was "smaller"
          return 1
        else
          comp = a <=> b
          return comp unless comp == 0
        end
      end # each

      # We've compared all components of both strings; if we've gotten
      # down here, they're totally the same
      return 0
    end

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
  end
end
