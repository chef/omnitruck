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

require 'opscode/version'

describe Opscode::Version::Rubygems do
  context "#initialize" do
    versions = [
                ["10.1.1",             [10,1,1, nil, nil]],
                ["10.1.1.alpha.1",     [10,1,1, "alpha.1", nil]],
                ["10.1.1.alpha.2",     [10,1,1, "alpha.2", nil]],
                ["10.1.1.beta.1",      [10,1,1, "beta.1", nil]],
                ["10.14.4-1",          [10, 14, 4, nil, "1"]],
                ["10.14.4-2",          [10, 14, 4, nil, "2"]],
                ["10.16.0-1",          [10, 16, 0, nil, "1"]],
                ["10.16.0.rc.0-1",     [10, 16, 0, "rc.0", "1"]],
                ["10.16.0.rc.1-1",     [10, 16, 0, "rc.1", "1"]],
                ["10.16.2-1",          [10, 16, 2, nil, "1"]]
               ]

    versions.each do |input|
      version_string, pieces = input
      major, minor, patch, prerelease, iteration = pieces

      it "works for #{version_string}" do
        v = Opscode::Version::Rubygems.new(version_string)
        v.major.should eq major
        v.minor.should eq minor
        v.patch.should eq patch
        v.prerelease.should eq prerelease
        v.build.should be_nil
        v.iteration.should eq iteration
      end
    end
  end

  describe "translating to a SemVer string" do
    let(:rubygems_version_string){"10.1.1.alpha.2"}
    let(:rubygems_version){Opscode::Version::Rubygems.new(rubygems_version_string)}

    it "generates a semver for a prerelease" do
      string = rubygems_version.to_semver_string
      string.should eq "10.1.1-alpha.2"
      semver = Opscode::Version::SemVer.new(string)
      (semver.prerelease?).should be true
    end
  end
end
