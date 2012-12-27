require 'opscode/versions'

# TODO: Need to test with regex_2 and regex_3 (see the code)

describe Opscode::Versions::GitDescribeVersion do
  context "#initialize" do

    subject{ Opscode::Versions::GitDescribeVersion.new(version_string) }

    context "10.16.2-49-g21353f0-1" do
      let(:version_string) { "10.16.2-49-g21353f0-1" }
      its(:major){ should eq 10 }
      its(:minor){ should eq 16 }
      its(:patch){ should eq 2 }
      its(:prerelease){ should be_nil }
      its(:build){ should eq "49.g21353f0.1" }
      its(:commits_since){ should eq 49 }
      its(:commit_sha){ should eq "21353f0" }
      its(:iteration){ should eq 1 }
    end

    context "10.16.2.rc.1-49-g21353f0-1" do
      let(:version_string) { "10.16.2.rc.1-49-g21353f0-1" }
      its(:major){ should eq 10 }
      its(:minor){ should eq 16 }
      its(:patch){ should eq 2 }
      its(:prerelease){ should eq "rc.1" }
      its(:build){ should eq "49.g21353f0.1" }
      its(:commits_since){ should eq 49 }
      its(:commit_sha){ should eq "21353f0" }
      its(:iteration){ should eq 1 }
    end

    context "10.16.2-rc.1-49-g21353f0-1" do
      let(:version_string) { "10.16.2-rc.1-49-g21353f0-1" }
      its(:major){ should eq 10 }
      its(:minor){ should eq 16 }
      its(:patch){ should eq 2 }
      its(:prerelease){ should eq "rc.1" }
      its(:build){ should eq "49.g21353f0.1" }
      its(:commits_since){ should eq 49 }
      its(:commit_sha){ should eq "21353f0" }
      its(:iteration){ should eq 1 }
    end

    context "10.16.2-alpha-49-g21353f0-1" do
      let(:version_string) { "10.16.2-alpha-49-g21353f0-1" }
      its(:major){ should eq 10 }
      its(:minor){ should eq 16 }
      its(:patch){ should eq 2 }
      its(:prerelease){ should eq "alpha" }
      its(:build){ should eq "49.g21353f0.1" }
      its(:commits_since){ should eq 49 }
      its(:commit_sha){ should eq "21353f0" }
      its(:iteration){ should eq 1 }
    end

    context "10.16.2-alpha-49-g21353f0" do
      let(:version_string) { "10.16.2-alpha-49-g21353f0" }
      its(:major){ should eq 10 }
      its(:minor){ should eq 16 }
      its(:patch){ should eq 2 }
      its(:prerelease){ should eq "alpha" }
      its(:build){ should eq "49.g21353f0.0" }
      its(:commits_since){ should eq 49 }
      its(:commit_sha){ should eq "21353f0" }
      its(:iteration){ should eq 0 }
    end

    def self.should_fail_for(version, reason=nil)
      it "fails for #{version}#{reason ? " (" + reason + ")" : ""}" do
        expect {Opscode::Versions::GitDescribeVersion.new(version)}.to raise_error(ArgumentError, "'#{version}' is not a valid Opscode 'git-describe' version string!")
      end
    end

    context "fails for semver-2.0.0-rc.1 versions" do
      ["1.0.0",
       "1.0.0-alpha.1",
       "1.0.0-alpha.1+build.deadbeef",
       "1.0.0+build.deadbeef"].each do |v|
        should_fail_for(v)
      end
    end

    context "with various flavors of bad git versions" do
      [["1.0.0-123-gdeadbeef-1", "too many SHA1 characters"],
       ["1.0.0-123-gdeadbe-1", "too few SHA1 characters"],
       ["1.0.0-123-gNOTHEX1-1", "illegal SHA1 characters"],
       ["1.0.0-123-g1234567-alpha", "non-numeric iteration"],
       ["1.0.0-alpha-poop-g1234567-1", "non-numeric 'commits_since'"],
       ["1.0.0-g1234567-1", "missing 'commits_since'"],
       ["1.0.0-123-1", "missing SHA1"],
      ].each do |pair|
        version, reason = pair
        should_fail_for(version, reason)
      end
    end
  end

  context "PARSING AS SEMVER" do
    it "works for 10.16.2-49-g21353f0-1, but THIS WON'T COMPARE NICELY WITH OTHER PROPER SemVers!" do
      s = Opscode::Versions::SemVer.new("10.16.2-49-g21353f0-1")
      s.major.should eq 10
      s.minor.should eq 16
      s.patch.should eq 2
      s.prerelease.should eq "49-g21353f0-1"
      s.build.should be_nil
    end
  end

  context "#to_s" do
    ["10.16.2-49-g21353f0-1"].each do |v|
      it "reconstructs the initial input of #{v}" do
        Opscode::Versions::GitDescribeVersion.new(v).to_s.should == v
      end
    end
  end

  versions = [
              "9.0.1-1-gdeadbee-1",
              "9.1.2-2-g1234567-1",
              "10.0.0-1-gabcdefg-1",
              "10.5.7-2-g21353f0-1",
              "10.20.2-2-gbbbbbbb-1",
              "10.20.2-3-gaaaaaaa-1",
              "9.0.1-2-gdeadbe1-1",
              "9.0.1-2-gdeadbe1-2", # Don't expect to actually see this, but what the hell...
              "9.0.1-2-gdeadbe2-1", # Don't expect to actually see this, but what the hell...
              "9.1.1-2-g1234567-1"
             ]
  let(:git_describe_versions){versions.map{|v| Opscode::Versions::GitDescribeVersion.new(v)}}
  let(:sorted_versions) do
    ["9.0.1-1-gdeadbee-1",
     "9.0.1-2-gdeadbe1-1",
     "9.0.1-2-gdeadbe1-2",
     "9.0.1-2-gdeadbe2-1",
     "9.1.1-2-g1234567-1",
     "9.1.2-2-g1234567-1",
     "10.0.0-1-gabcdefg-1",
     "10.5.7-2-g21353f0-1",
     "10.20.2-2-gbbbbbbb-1",
     "10.20.2-3-gaaaaaaa-1"
    ].map{|v| Opscode::Versions::GitDescribeVersion.new(v)}
  end

  describe "<=>" do
    it "sorts all properly" do
      git_describe_versions.sort.should eq sorted_versions
    end

    it "finds the min" do
      git_describe_versions.min.should eq Opscode::Versions::GitDescribeVersion.new("9.0.1-1-gdeadbee-1")
    end

    it "finds the max" do
      git_describe_versions.max.should eq Opscode::Versions::GitDescribeVersion.new("10.20.2-3-gaaaaaaa-1")
    end
  end

  describe "build qualifiers" do

    context "no GitDescribeVersion can be a proper release" do
      versions.each do |v|
        it "#{v} isn't a release" do
          Opscode::Versions::GitDescribeVersion.new(v).release?.should be_false
        end
      end
    end

    context "no GitDescribeVersion can be a proper pre-release" do
      versions.each do |v|
        it "#{v} isn't a pre-release" do
          Opscode::Versions::GitDescribeVersion.new(v).prerelease?.should be_false
        end
      end
    end

    context "every GitDescribeVersion is a nightly release" do
      versions.each do |v|
        it "#{v} is a nightly" do
          Opscode::Versions::GitDescribeVersion.new(v).nightly?.should be_true
        end
      end
    end
  end

end

