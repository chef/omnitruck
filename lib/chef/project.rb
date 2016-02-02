class Chef
  class Project
    KNOWN_PROJECTS = %w(
      angrychef
      angry-omnibus-toolchain
      chef
      chef-server
      chefdk
      delivery-cli
      omnibus-toolchain
      push-jobs-client
    )

    attr_reader :name
    attr_reader :channel

    def initialize(name, channel)
      @name = name
      @channel = channel
    end

    # prefix key name of the release manifest for this project
    def release_manifest_name
      "#{name}-release-manifest"
    end

    def manifests
      @manifests ||= begin
                       keys_for_project = channel.manifests.select { |key| File.dirname(key) == release_manifest_name }
                       keys_for_project.map { |k| File.basename(k) }
                     end
      if @manifests.length == 0
        debug("Remote manifest was empty for #{release_manifest_name} in the channel '#{channel.name}'")
      end
      @manifests
    end

    def get_platform_names
      begin
        channel.download_manifest(key_for("#{name}-platform-names.json"))
      rescue Chef::Channel::ManifestNotFound => e
        '{}'
      end
    end

    def download_manifest(manifest)
      channel.download_manifest(key_for(manifest))
    end

    def debug(msg)
      puts msg
    end

    def key_for(manifest)
      File.join(release_manifest_name, manifest)
    end

    def manifest_md5_for(key)
      channel.manifest_md5_for("#{release_manifest_name}/#{key}")
    end

    def manifest_last_modified_for(key)
      channel.manifest_last_modified_for("#{release_manifest_name}/#{key}")
    end
  end
end
