class Chef
  class Project
    PROJECTS = ['chef', 'chef-server', 'chefdk', 'angrychef']

    attr_reader :name
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
  end
end
