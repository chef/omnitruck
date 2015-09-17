class Chef
  class Project
    PROJECTS = ['chef', 'chef-server', 'chefdk', 'angrychef']

    attr_reader :name
    attr_reader :channel
    attr_reader :build_list_v1
    attr_reader :build_list_v2
    attr_reader :platform_names

    def initialize(name, channel, build_list_v1, build_list_v2, platform_names)
      @name = name
      @channel = channel
      @build_list_v1 = build_list_v1
      @build_list_v2 = build_list_v2
      @platform_names = platform_names
    end

    def self.load(name, channel)
      Chef::Project.new(
        name,
        channel,
        channel.metadata_file("build-#{name}-list-v1.json"),
        channel.metadata_file("build-#{name}-list-v2.json"),
        channel.metadata_file("#{name}-platform-names.json")
      )
    end

    def self.all_projects_for_channel(channel)
      PROJECTS.map do |p|
        Project.load(p, channel)
      end
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
        debug("Remote manifest was empty for s3://#{bucket_name}/#{release_manifest_name}, if this occurs, please check your config file.")
      end
      @manifests
    end

    def get_platform_names
      channel.download_manifest(key_for("#{name}-platform-names.json"))
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
