class Chef
  class Project
    KNOWN_PROJECTS = %w( chef chef-server chefdk angrychef )

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
        debug("Remote manifest was empty for #{release_manifest_name} in the channel '#{channel.name}")
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
  end
end
