#--
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Opscode, Inc.
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

describe Opscode::Version::SemVer do
  context "#initialize" do
    it "works for 1.0.0" do
      s = Opscode::Version::SemVer.new("1.0.0")
      s.major.should eq 1
      s.minor.should eq 0
      s.patch.should eq 0
      s.prerelease.should be_nil
      s.build.should be_nil
    end

    it "works for 1.0.0-alpha.1" do
      s = Opscode::Version::SemVer.new("1.0.0-alpha.1")
      s.major.should eq 1
      s.minor.should eq 0
      s.patch.should eq 0
      s.prerelease.should eq "alpha.1"
      s.build.should be_nil
    end

    it "works for 1.0.0-alpha.1+build.deadbeef" do
      s = Opscode::Version::SemVer.new("1.0.0-alpha.1+build.deadbeef")
      s.major.should eq 1
      s.minor.should eq 0
      s.patch.should eq 0
      s.prerelease.should eq "alpha.1"
      s.build.should eq "build.deadbeef"
    end

    it "works for 1.0.0+build.deadbeef" do
      s = Opscode::Version::SemVer.new("1.0.0+build.deadbeef")
      s.major.should eq 1
      s.minor.should eq 0
      s.patch.should eq 0
      s.prerelease.should be_nil
      s.build.should eq "build.deadbeef"
    end

    it "rejects bogus input" do
      v = "One.does.not-simply+implement.SemVer"
      expect { Opscode::Version::SemVer.new(v) }.to raise_error(ArgumentError, "'#{v}' is not a valid semver version string!")
    end
  end

  context "#to_s" do
    ["1.0.0",
     "1.0.0-alpha.1",
     "1.0.0-alpha.1+build.123",
     "1.0.0+build.456"].each do |v|
      it "reconstructs the initial input of #{v}" do
        Opscode::Version::SemVer.new(v).to_s.should == v
      end
    end
  end

  context "SemVer 2.0.0-rc1 Examples" do
    let(:versions){["1.0.0-beta.2",
                    "1.0.0-alpha",
                    "1.0.0-rc.1+build.1",
                    "1.0.0",
                    "1.0.0-beta.11",
                    "1.0.0+0.3.7",
                    "1.0.0-rc.1",
                    "1.0.0-alpha.1",
                    "1.3.7+build.2.b8f12d7",
                    "1.3.7+build.11.e0f985a",
                    "1.3.7+build"]}
    let(:semvers){versions.map{|v| Opscode::Version::SemVer.new(v)}}
    let(:sorted_semvers) do
      ["1.0.0-alpha",
       "1.0.0-alpha.1",
       "1.0.0-beta.2",
       "1.0.0-beta.11",
       "1.0.0-rc.1",
       "1.0.0-rc.1+build.1",
       "1.0.0",
       "1.0.0+0.3.7",
       "1.3.7+build",
       "1.3.7+build.2.b8f12d7",
       "1.3.7+build.11.e0f985a"].map{|v| Opscode::Version::SemVer.new(v)}
    end

    describe "<=>" do
      it "sorts all properly" do
        semvers.sort.should eq sorted_semvers
      end

      it "finds the min" do
        semvers.min.should eq Opscode::Version::SemVer.new("1.0.0-alpha")
      end

      it "finds the max" do
        semvers.max.should eq Opscode::Version::SemVer.new("1.3.7+build.11.e0f985a")
      end
    end

    describe "build qualifiers" do
      subject{Opscode::Version::SemVer.new(version)}

      context "Release" do
        let(:version){"1.0.0"}
        its(:release?){should be_true}
        its(:prerelease?){should be_false}
        its(:release_nightly?){should be_false}
        its(:prerelease_nightly?){should be_false}
        its(:nightly?){should be_false}
      end

      context "Pre-release" do
        let(:version){"1.0.0-alpha.1"}
        its(:release?){should be_false}
        its(:prerelease?){should be_true}
        its(:release_nightly?){should be_false}
        its(:prerelease_nightly?){should be_false}
        its(:nightly?){should be_false}
      end

      context "Nightly pre-release build" do
        let(:version){"1.0.0-alpha.1+build.123"}
        its(:release?){should be_false}
        its(:prerelease?){should be_false}
        its(:release_nightly?){should be_false}
        its(:prerelease_nightly?){should be_true}
        its(:nightly?){should be_true}
      end

      context "Nightly release build" do
        let(:version){"1.0.0+build.123"}
        its(:release?){should be_false}
        its(:prerelease?){should be_false}
        its(:release_nightly?){should be_true}
        its(:prerelease_nightly?){should be_false}
        its(:nightly?){should be_true}
      end
    end

    describe "Filtering by Build Qualifiers" do
      context "releases only" do
        it "works" do
          semvers.select(&:release?).should eq [Opscode::Version::SemVer.new("1.0.0")]
        end
      end

      context "prereleases only" do
        it "works" do
          filtered = semvers.select(&:prerelease?)
          filtered.sort.should eq(["1.0.0-alpha",
                                   "1.0.0-alpha.1",
                                   "1.0.0-beta.2",
                                   "1.0.0-beta.11",
                                   "1.0.0-rc.1"
                                  ].map{|v| Opscode::Version::SemVer.new(v)})
        end
      end

      context "release nightlies only" do
        it "works" do
          filtered = semvers.select(&:release_nightly?)
          filtered.sort.should eq(["1.0.0+0.3.7",
                                   "1.3.7+build",
                                   "1.3.7+build.2.b8f12d7",
                                   "1.3.7+build.11.e0f985a"
                                  ].map{|v| Opscode::Version::SemVer.new(v)})
        end
      end

      context "prereleases nightlies only" do
        it "works" do
          filtered = semvers.select(&:prerelease_nightly?)
          filtered.should eq [Opscode::Version::SemVer.new("1.0.0-rc.1+build.1")]
        end
      end

    end

  end

end
