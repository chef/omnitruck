require 'fileutils'

module OmnitruckVerifier
  class MetadataCache

    CACHE_DIR = File.expand_path("~/.omnibus-verify")
    METADATA_CACHE = File.expand_path("release_metadata", CACHE_DIR)

    # Ensure top-level cache dir is created
    def self.ensure_created
      FileUtils.mkdir_p(METADATA_CACHE)
    end

    attr_reader :version

    def initialize(version)
      @version = version
    end

    def store
      FileUtils.mkdir(metadata_dir) unless File.directory?(metadata_dir)
      yield self
    rescue Exception
      FileUtils.rm_rf(metadata_dir)
      raise
    end

    def metadata_dir
      File.join(METADATA_CACHE, version)
    end

    def already_cached?
      File.exist?(metadata_file)
    end

    def metadata_file
      File.join(metadata_dir, "metadata.json")
    end

    def md5_file
      File.join(metadata_dir, "md5")
    end

    def sha256_file
      File.join(metadata_dir, "sha256")
    end

    def sha512_file
      File.join(metadata_dir, "sha512")
    end

    def cached_md5
      IO.read(md5_file).strip
    end

    def has_version?(version)
      FileUtils.mkdir(metadata_dir) unless File.directory?(metadata_dir)
    end
  end
end
