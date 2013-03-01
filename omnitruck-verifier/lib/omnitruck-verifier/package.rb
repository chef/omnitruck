require 'omnitruck-verifier/bucket_lister'

module OmnitruckVerifier
  class Package < Struct.new(:key, :md5)

    PUBLISHED_PKG_BUCKET = "opscode-omnitruck-release".freeze

    def self.all_by_relpath
      packages_by_relpath = {}
      BucketLister.new(PUBLISHED_PKG_BUCKET).fetch do |key, md5|
        maybe_package = new(key, md5)
        packages_by_relpath[maybe_package.relpath] = maybe_package if maybe_package.valid_pkg_name?
      end
      packages_by_relpath
    end

    attr_accessor :expected_md5

    # relpath in the metadata files starts with a "/"
    def relpath
      "/#{key}"
    end

    def valid_pkg_name?
      key !~ /^chef/
    end

    def valid_md5?
      expected_md5 == md5
    end

    def explain_error
      <<-E
metadata of #{relpath} doesn't match.
  expected MD5 (cached metadata): #{expected_md5}
  actual MD5 (from AWS): #{md5}
E
    end

  end
end
