require 'opscode/versions'

describe Opscode::Versions::RubygemsVersion do
  context "#initialize" do
    versions = [
                ["10.1.1",         [10,1,1, nil, nil]],
                ["10.1.1.alpha.1", [10,1,1, "alpha.1", nil]],
                ["10.1.1.alpha.2", [10,1,1, "alpha.2", nil]],
                ["10.1.1.beta.1",  [10,1,1, "beta.1", nil]],
                ["10.14.4-1",      [10, 14, 4, nil, "1"]],
                ["10.14.4-2",      [10, 14, 4, nil, "2"]],
                ["10.16.0-1",      [10, 16, 0, nil, "1"]],
                ["10.16.0.rc.0-1", [10, 16, 0, "rc.0", "1"]],
                ["10.16.0.rc.1-1", [10, 16, 0, "rc.1", "1"]],
                ["10.16.2-1",      [10, 16, 2, nil, "1"]]
               ]

    versions.each do |input|
      version_string, pieces = input
      major, minor, patch, prerelease, iteration = pieces

      it "works for #{version_string}" do
        v = Opscode::Versions::RubygemsVersion.new(version_string)
        v.major.should eq major
        v.minor.should eq minor
        v.patch.should eq patch
        v.prerelease.should eq prerelease
        v.build.should be_nil
        v.iteration.should eq iteration
      end
    end
  end
end
